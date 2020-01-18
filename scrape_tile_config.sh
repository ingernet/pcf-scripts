#!/usr/local/bin/bash
# REQUIRED: BASH 4+

function usage(){
	echo ""
	echo "Syntax error. Exiting."
	echo "USAGE: "
	echo "    ${0} <tile-slug> <opsman-env>" 
    echo "    example: ${0} cf env1"
    echo "    This script assumes that you have an OpsMan env-<opsman-env>.yml file."
    echo "    Look at env-sample.yml for reference."
	echo ""
}

## LIST OF OPSMAN TARGETS
## If Ops Man is only available via IP address, you can get that from the tfstate file
declare -A OPSMAN_TARGETS=(
        [env1]="<OPSMAN1-TARGET-FQDN>"
        [env2]="<OPSMAN2-TARGET-FQDN>"
        [env3]="$(terraform output -state <PATH-TO-TFSTATE-FILE> ops_manager_public_ip)"
)

## LET'S SEE IF THEY'RE EVEN DOING THIS RIGHT
if [ -z ${2} ]; then
    printf "\nNot enough arguments. Please review usage."
    usage && exit 1;
fi

TILE_SLUG=${1}
OPSMAN_ENV=${2}

if [[ ! "${OPSMAN_TARGETS[${OPSMAN_ENV}]}" ]]; then
    echo "invalid environment variable!"
		usage && exit 1;
fi

OPSMAN_TARGET=${OPSMAN_TARGETS[${OPSMAN_ENV}]}
NOW=$(date "+%Y%m%d%H%M%S")

### Get some stuff from CP Terraform output
LB_DNS=$(jq -r '.modules[].resources["aws_lb.control_plane"].primary.attributes? | select(.dns_name != null)| .dns_name' terraform-state/terraform-cp.tfstate)


### Grab some stuff from the CP Credhub
source ./target-credhub.sh controlplane
AWS_ACCESS_KEY_ID="$(credhub get -n '/p-bosh/concourse/iaas-configuration_access_key_id' -j  | jq -r '.value')"
AWS_SECRET_ACCESS_KEY="$(credhub get -n '/p-bosh/concourse/iaas-configuration_secret_access_key' -j  | jq -r '.value')"
CREDHUB_SECRET="$(credhub get -n '/p-bosh/concourse/concourse_to_credhub_secret' -j | jq -r '.value')"
OPSMAN_ENVFILE=env-${OPSMAN_ENV}.yml
SCRAPEFILE="temp-tile-${TILE_SLUG}-${OPSMAN_ENV}-${NOW}.yml"
SCRAPEFILE_SECRETS="temp-tile-${TILE_SLUG}-${OPSMAN_ENV}-UNREDACTED-${NOW}.yml"

echo "Scraping config for ${TILE_SLUG} from ${OPSMAN_TARGET}..."
om3 --env ${OPSMAN_ENVFILE} --target ${OPSMAN_TARGET} -k staged-config  --include-placeholders --product-name ${TILE_SLUG} > ${SCRAPEFILE}
echo "Redacted config scraped. You can find it in: ${SCRAPEFILE}"

om3 --env ${OPSMAN_ENVFILE} --target ${OPSMAN_TARGET} -k staged-config  --include-credentials --product-name ${TILE_SLUG} > ${SCRAPEFILE_SECRETS}
echo "UNREDACTED config scraped. You can find it in: ${SCRAPEFILE_SECRETS}"

