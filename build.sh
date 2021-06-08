#
# Download Salesforce CLI and install it
#

# Setup SFDX environment variables
export CLIURL=https://developer.salesforce.com/media/salesforce-cli/sfdx/channels/stable/sfdx-linux-x64.tar.xz
export SFDX_AUTOUPDATE_DISABLE=false
export SFDX_USE_GENERIC_UNIX_KEYCHAIN=true
export SFDX_DOMAIN_RETRY=300
export SFDX_DISABLE_APP_HUB=true
export SFDX_LOG_LEVEL=DEBUG
export ROOTDIR=force-app/main/default/
export TESTLEVEL=RunLocalTests
export PACKAGENAME=0Ho1U000000CaUzSAK
export PACKAGEVERSION=""

# Create sfdx directory
mkdir ~/sfdx
# Install CLI
# By default, the script installs the current version of Salesforce CLI. To install the release candidate, set the DX_CLI_URL_CUSTOM local variable to the appropriate URL
wget -qO- ${DX_CLI_URL_CUSTOM-$CLIURL} | tar xJ -C ~/sfdx --strip-components 1
export PATH=~/sfdx/bin:$PATH

# Output CLI version and plug-in information
sfdx --version
sfdx plugins --core

# Decrypt server key
openssl enc -nosalt -aes-256-cbc -d -in assets/server.key.enc -out assets/server.key -base64 -K $DECRYPTION_KEY -iv $DECRYPTION_IV


# Authenticate to Salesforce using server key
sfdx force:auth:jwt:grant --clientid $CONSUMER_KEY --jwtkeyfile assets/server.key --username $USER_NAME --setdefaultdevhubusername --setalias HubOrg

# Create scratch org
sfdx force:org:create --targetdevhubusername HubOrg --setdefaultusername --definitionfile config/project-scratch-def.json --setalias ciorg --wait 10 --durationdays 1
sfdx force:org:display --targetusername ciorg

# Push source to scratch org
sfdx force:source:push --targetusername ciorg

# Run unit tests in scratch org
sfdx force:apex:test:run --targetusername ciorg --wait 10 --resultformat tap --codecoverage --testlevel $TESTLEVEL

# Delete scratch org
sfdx force:org:delete --targetusername ciorg --noprompt

# Create package version
PACKAGEVERSION="$(sfdx force:package:version:create --package $PACKAGENAME --installationkeybypass --wait 10 --json --targetdevhubusername HubOrg | jq '.result.SubscriberPackageVersionId' | tr -d '"')"
sleep 300 # Wait for package replication.
echo $PACKAGEVERSION

# Create scratch org
sfdx force:org:create --targetdevhubusername HubOrg --setdefaultusername --definitionfile config/project-scratch-def.json --setalias installorg --wait 10 --durationdays 1
sfdx force:org:display --targetusername installorg

# Install package in scratch org
sfdx force:package:install --package $PACKAGEVERSION --wait 10 --targetusername installorg

# Run unit tests in scratch org
sfdx force:apex:test:run --targetusername installorg --wait 10 --resultformat tap --codecoverage --testlevel $TESTLEVEL

# Delete scratch org
sfdx force:org:delete --targetusername installorg --noprompt
