REM
REM Download Salesforce CLI and install it
REM

REM Decrypt server key
openssl aes-256-cbc -d -md md5 -in assets/server.key.enc -out assets/server.key -k %bamboo_SERVER_KEY_PASSWORD%

REM Setup SFDX environment variables
set SFDX_AUTOUPDATE_DISABLE="false"
set SFDX_USE_GENERIC_UNIX_KEYCHAIN="true"
set SFDX_DOMAIN_RETRY="300"
set SFDX_DISABLE_APP_HUB="true"
set SFDX_LOG_LEVEL="DEBUG"
set ROOTDIR="force-app/main/default/"
set TESTLEVEL="RunLocalTests"
set PACKAGENAME="0Ho1U000000CaUzSAK"
set PACKAGEVERSION=""

REM Output CLI version and plug-in information
sfdx --version
sfdx plugins --core

REM
REM Deploy metadata to Salesforce
REM

REM Authenticate to Salesforce using the server key
sfdx force:auth:jwt:grant --clientid %bamboo_SF_CONSUMER_KEY% --jwtkeyfile assets/server.key --username %bamboo_SF_USERNAME% --setdefaultdevhubusername --setalias HubOrg

REM Create scratch org
sfdx force:org:create --targetdevhubusername HubOrg --setdefaultusername --definitionfile config/project-scratch-def.json --setalias ciorg --wait 10 --durationdays 1
sfdx force:org:display --targetusername ciorg

REM Push source to scratch org
sfdx force:source:push --targetusername ciorg

REM Run unit tests in the scratch org
sfdx force:apex:test:run --targetusername ciorg --wait 10 --resultformat tap --codecoverage --testlevel %TESTLEVEL%

REM Delete scratch org
sfdx force:org:delete --targetusername ciorg --noprompt

REM Create package version
for /f "delims=" %%a in ('sfdx force:package:version:create --package %PACKAGENAME% --installationkeybypass --wait 10 --json --targetdevhubusername HubOrg | jq '.result.SubscriberPackageVersionId'') do @set PACKAGEVERSION=%%a

REM Wait for package replication
sleep 300
echo $PACKAGEVERSION

REM Create scratch org
sfdx force:org:create --targetdevhubusername HubOrg --setdefaultusername --definitionfile config/project-scratch-def.json --setalias installorg --wait 10 --durationdays 1
sfdx force:org:display --targetusername installorg

REM Install package in scratch org
sfdx force:package:install --package %PACKAGEVERSION% --wait 10 --targetusername installorg

REM Run unit tests in scratch org
sfdx force:apex:test:run --targetusername installorg --wait 10 --resultformat tap --codecoverage --testlevel %TESTLEVEL%

REM Delete scratch org
sfdx force:org:delete --targetusername installorg --noprompt
