#!/usr/local/bin/bash
# REQUIRED: BASH 4+
# This command that lets you _see_ the config without breaking the director config. 


function usage(){
        echo ""
        echo "Syntax error. Exiting."
        echo "USAGE: "
        echo "    ${0} <env-shortcode>" 
    echo "    example: ${0} env1"
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
if [ -z ${1} ]; then
    printf "\nNot enough arguments. Please review usage."
    usage && exit 1;
fi

OPSMAN_ENV=${1}

if [[ ! "${OPSMAN_TARGETS[${OPSMAN_ENV}]}" ]]; then
    echo "invalid environment variable!"
                usage && exit 1;
fi

NOW=$(date "+%Y%m%d%H%M%S")
OPSMAN_TARGET=${OPSMAN_TARGETS[${OPSMAN_ENV}]}
OPSMAN_ENVFILE=env-${OPSMAN_ENV}.yml
SCRAPEFILE="temp-director-${OPSMAN_ENV}-${NOW}.yml"
SCRAPEFILE_SECRETS="temp-director-${OPSMAN_ENV}-UNREDACTED-${NOW}.yml"

om --env ${OPSMAN_ENVFILE} --target ${OPSMAN_TARGET} staged-director-config  --no-redact --include-placeholders > ${SCRAPEFILE}
om --env ${OPSMAN_ENVFILE} --target ${OPSMAN_TARGET} staged-director-config  --no-redact > ${SCRAPEFILE_SECRETS}

echo "Config scraped. You can find it in: ${SCRAPEFILE}"
echo "Unredacted config scraped. You can find it in: ${SCRAPEFILE_SECRETS}"
