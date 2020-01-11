#!/bin/bash

export OPSMAN_TARGET=localhost
export OPSMAN_ADMIN=opsman_admin

# get the password for the opsman's admin user (admin on control plane; opsman_admin everywhere else) from user input
echo "Please enter the password for the Ops Manager's admin user (from LastPass): "
read OPSMAN_PASSWORD

if [ $OPSMAN_PASSWORD == "" ]; then
  printf "Ops Manager password required\n" && return
fi

##### A. Authenticate on Ops Manager ####
# 1. get token:
uaac target https://${OPSMAN_TARGET}/uaa --skip ssl-validation
uaac token owner get opsman ${OPSMAN_ADMIN} -s "" -p ${OPSMAN_PASSWORD}

# 2. get the UAA token from ops Manager 
IFS=': ' && read -a TMP_UAAC_TOKEN <<< "$(uaac context ${OPSMAN_ADMIN} | grep access_token)"
# export TMP_UAAC_TOKEN="<contents of access_token field>" 
#    ^ think i got this cracked above, but keeping this here as a reminder of the manual step 
#       we used to have to do because for some reason cf-uaac authors chose not to output in json


##### B. set ENV vars with ops man api query ops manager api token for bosh_commandline_credentials #####
# bosh_commandline_credentials
# This sets: BOSH_ENVIRONMENT, BOSH_CLIENT, BOSH_CLIENT_SECRET, and BOSH_CA_CERT
export $(curl -ks "https://${OPSMAN_TARGET}/api/v0/deployed/director/credentials/bosh_commandline_credentials" -X GET -H "Authorization: Bearer ${TMP_UAAC_TOKEN}" | jq -r '.credential' | sed 's/ bosh //')


##### C. query Ops Manager api for pas credentials: #####
# 1. list deployments and look for pas:
CF_GUID=$(curl -ks "https://${OPSMAN_TARGET}/api/v0/deployed/products" -X GET -H "Authorization: Bearer ${TMP_UAAC_TOKEN}"  | jq -r '.[] | select(.type == "cf") | .installation_name')

# 2. get the specific cred you need from pas:
export CREDHUB_CLIENT=$(curl -ks "https://${OPSMAN_TARGET}/api/v0/deployed/products/${CF_GUID}/credentials/.uaa.credhub_admin_client_client_credentials" -X GET -H "Authorization: Bearer ${TMP_UAAC_TOKEN}" | jq -r '.credential.value.identity')
export CREDHUB_SECRET=$(curl -ks "https://${OPSMAN_TARGET}/api/v0/deployed/products/${CF_GUID}/credentials/.uaa.credhub_admin_client_client_credentials" -X GET -H "Authorization: Bearer ${TMP_UAAC_TOKEN}" | jq -r '.credential.value.password')


##### D. check for host records in /etc/hosts
# IF /ETC/HOSTS IS MISSING HOST RECORDS NEEDED BY THIS SCRIPT, EXIT
if ! grep -q "credhub.service.cf.internal" /etc/hosts || ! grep -q "uaa.service.cf.internal" /etc/hosts; then 
  # Get bosh env alias based on director ip - gotta use double quotes on this bc bash string interpolation meets jq
  export BOSH_ENV_ALIAS=$(bosh envs --json | jq -r ".Tables[0].Rows[] | select(.url == \"${BOSH_ENVIRONMENT}\") | .alias")

  printf "\n\n\nALERT! ATTENZIONE! ACHTUNG!\n\n It doesn't appear that the /etc/hosts file has been fully set up:\n"

  cat /etc/hosts;

  printf "\n\n Please ensure that these entries exist: \n  - credhub.service.cf.internal\n  - uaa.service.cf.internal\n\n"

  printf "Here's a valid IP address for one of PAS's Credhub instances: "
  bosh -e ${BOSH_ENV_ALIAS} -d ${CF_GUID} vms --json | jq -r '[.Tables[0].Rows[] | select(.instance | startswith("credhub/"))][0] | .ips'

  printf "\n\nHere's a valid IP address for one of PAS's UAA instances: "
  bosh -e $BOSH_ENV_ALIAS -d ${CF_GUID} vms --json | jq -r '[.Tables[0].Rows[] | select(.instance | startswith("uaa"))][0] | .ips'  

  printf "This script won't work without that. Go ahead and take care of it (sudo -i; vim /etc/hosts); I'll be here waiting for you when you get back.\n\n"
  return 1;
fi




