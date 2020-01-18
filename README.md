# pcf-scripts
shell scripts that make PCF life easier

## Contents

### Config file samples
Both of these config file samples are used by target-credhub.sh:

- *env-sample.yml:* includes the opsman admin username & password + server decryption passphrase. passphrase is included because there are scripts using this file that _aren't_ in this repo, but which need to reboot the Opsman VM when they're done running. If you know, you know. 
- *opsman-ssl-private-key-sample.pem:* the private key portion of the Ops Manager's SSL Cert keypair.

### Credhub Scripts
These scripts speed up the process of authenticating on a Credhub server:

- *target-credhub.sh:* a huge utility player in this repo. allows you to target either the control plane Opsman's internal Credhub, or a standalone Credhub instance. Used by lots of scripts.
- *opsman-target-credhub.sh:* you can run this on any Ops Manager VM to access its internal PAS Credhub. This is super handy for debugging Spring Cloud Config Server/app secrets storage issues. I wrote it because I got sick of typing NINE (9) CLI commands using an API and multiple CLI tools just to authenticate on the danged PAS Credhub. You are welcome.

### OM scripts
These scripts allow you to scrape a staged tile or director config. Super handy when you've made a runtime change in the UI and need to get the attributes in YML form for your Concourse pipeline. 

- *scrape_director_config.sh:* scrapes redacted and unredacted director configs
- *scrape_tile_config.sh:* scrapes redacted and unredacted config from the tile of your choice.

# Authors:
- Inger Klekacz
