#!/bin/bash

# A script that allows you to either access the Control Plane's built-in Credhub, 
# or the stanadalone Credhub instance used by Concourse.
#
# DO NOT RUN THIS, JUST SOURCE THIS. LIKE THIS. `source ./target-concourse-credhub.sh [controlplane|concourse]`

## SET UP
OPSMAN_KEY="<PATH-TO-CONTROLPLANE-OPS-MANAGER-PRIVATE-KEY>"
CP_TF="<PATH-TO-CONTROLPLANE-TFSTATE-FILE>"
CP_ENV="<PATH-TO-CONTROLPLANE-ENV.YML-FILE>"


## THE MEAT
function usage(){
	echo ""
	echo "Syntax error. Exiting."
	echo "USAGE: "
	echo "    source ${BASH_SOURCE[0]} [controlplane | concourse]"
	echo ""
}


# Exit if this is not being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]];then
	usage; 
	return 1;

# Exit if no parameters included
elif [[ -z ${1} ]]; then
	usage;
	return 1;

# Exit if wrong parameters included
elif [[ ${1} != "controlplane" ]] && [[ ${1} != "concourse" ]]; then
	usage;
	return 1;

elif [[ ! -e ${OPSMAN_KEY}  ]]; then
    echo "REQUIRED CONFIG FILE IS MISSING: ${OPSMAN_KEY}";
    return 1;

elif [[ ! -e ${CP_TF} ]]; then
    echo "REQUIRED CONFIG FILE IS MISSING: ${CP_TF}";
    return 1;

elif [[ ! -e ${CP_ENV} ]]; then
    echo "REQUIRED CONFIG FILE IS MISSING: ${CP_ENV}";
    return 1;

# If "controlplane" specified, target the Control Plane Credhub instance
elif [[ ${1} == "controlplane" ]]; then
	CP_OPSMAN_IP=$(terraform output -state ${CP_TF} ops_manager_public_ip)
	eval "$(om --target $CP_OPSMAN_IP --env env-cp.yml bosh-env -i ${OPSMAN_KEY})"

	echo "Connecting to the Control Plane's Credhub..."
	credhub login

# If "concourse" specified, target the Concourse Credhub instance
elif [[ ${1} == "concourse" ]]; then
	# echo "success! ${1}"

	CP_OPSMAN_IP=$(terraform output -state ${CP_TF} ops_manager_public_ip)
	eval "$(om --target $CP_OPSMAN_IP --env env-cp.yml bosh-env -i ./keys/controlplane_opsman_key.pem)"
    LB_DNS=$(jq -r '.modules[].resources["aws_lb.control_plane"].primary.attributes? | select(.dns_name != null)| .dns_name' ${CP_TF})
	CONCOURSE_URL="https://${LB_DNS}"
	if [ -z "$CONCOURSE_URL" ]; then
		echo "CONCOURSE_URL is unset! Exiting..."
		return 1
	fi

	# this script requires that we eval "$(om bosh-env)" first.
	# (make sure that has been done)
	if [ -z "$CREDHUB_CLIENT" ]; then
		echo "CREDHUB_CLIENT unset!  Please run:"
		echo "   eval \"$(om bosh-env)\""
		return 1
	fi

	# login to the BOSH director Credhub using info from om
	echo "Connecting to Control Plane Credhub temporarily to get credentials for the standalone Concourse Credhub...."
	credhub login

	# figure out the path for the vars we want
	# (this depends on what we used as our BBL_ENVIRONMENT_NAME)
	SECRET_PATH=$(credhub find -n concourse_to_credhub_secret | grep name | awk '{print $NF}')
	CA_PATH=$(credhub find -n atc_ca | grep name | awk '{print $NF}')

	# read the CA certificate and client secret from the BOSH director's Credhub
	echo "Reading environment details from Control Plane's internal Credhub...."
	SECRET=$(credhub get -n $SECRET_PATH | grep value | awk '{print $NF}')
	CERT=$(credhub get -n $CA_PATH -k certificate)

	# reset Credhub environment variables to point at the Concourse Credhub
	unset CREDHUB_PROXY
	export CREDHUB_SERVER="$CONCOURSE_URL:8844"
	export CREDHUB_CLIENT=concourse_to_credhub
	export CREDHUB_SECRET="$SECRET"
	export CREDHUB_CA_CERT=$CERT

	echo "Connecting to Concourse's Credhub..."
	credhub login
fi
