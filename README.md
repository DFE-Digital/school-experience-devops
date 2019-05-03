# school-experience-devops

To completely bootstrap an environment including the building of the school-experience image, seeding the database and pushing of the locally built image to the registry...

Prerequisites:

There must a Azure Key Vault set up for which the account running the `deploy.sh` [has 'get' and 'list' access](https://docs.microsoft.com/en-us/azure/key-vault/quick-create-net#assign-permissions-to-your-application-to-read-secrets-from-key-vault). The key vault must have the following secrets

* `postgresAdminPassword`
* `postgresUserPassword`
* `slackWebhook` - required but will be ignored if slackEnv is set to '' 

**The deploy script uses the `--template-uri` i.e. remote templates. This is required because it references Azure Key Vaults's with via [dynamic ids](https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-manager-keyvault-parameter#reference-secrets-with-dynamic-id)** 

Usage: 

    BUILD_APP=true ./deploy.sh -i <subscriptionId> -g <resourceGroupName> -n <deploymentName> -l <resourceGroupLocation> -m <registryName> -o <vaultResourceGroup> -p <vaultName> -q <databaseServerName> -r <databaseName> -s <servicePlanName> -w <sitesName> -t <redisName> -v <environmentName> -b <branch of this repo>

Example:

    BUILD_APP=true ./deploy.sh -i XXXX-XXXX-XXXX-XXXX -g schoolExperienceGroupTest -n schoolExperienceDeployment -l uksouth -m schoolExperienceRegistryTest -o schoolExperienceVaultGroup -p schoolExperienceVault -q schoolexperience-db-test -r school_experience_test -s schoolExperienceServicePlanTest -w schoolexperience-test -t schoolexperience-redis-test -v dev -b master

To only do the ARM template deployment 

Usage:

    ./deploy.sh -i <subscriptionId> -g <resourceGroupName> -n <deploymentName> -l <resourceGroupLocation> -m <registryName> -o <vaultResourceGroup> -p <vaultName> -q <databaseServerName> -r <databaseName> -s <servicePlanName> -w <sitesName> -t <redisName> -v <environmentName> -b <branch of this repo>

## Upload the SSL certificate

As background read

https://docs.microsoft.com/en-us/azure/app-service/app-service-web-tutorial-custom-ssl?toc=%2fazure%2fapp-service%2fcontainers%2ftoc.json

It is assumed that the user is in posession of a certificate in pfx format and knows the password for this pfx file.

This can be done manually or via the command line. Storing the certificates in a key vault and then creating the website certificate resource is just adding additional steps (the certificate still has to be uploaded into the key vault, and NOT as a certificate but as a secret with lots of hoops and loops that have to be gone through via PowerShell). Here is the command line steps

CERTIFICATE_FILE=<the location of the pfx file>
WEBAPP_NAME=<the name of the webapp>
GROUP_NAME=<the name of the resource group>
read -s CERTIFICATE_PASSWORD
CERTIFICATE_NAME=$(az webapp config ssl upload --certificate-password $CERTIFICATE_PASSWORD --certificate-file $CERTIFICATE_FILE -n $WEBAPP_NAME -g $GROUP_NAME -o tsv --query name)
echo $CERTIFICATE_NAME

The cerificate name is now stored as a variable in the CD pipeline.

## Adding a custom domain corresponding to the SSL certificate that has been uploaded.

This is done via an Azure Resource Manager (ARM) template.

WEBAPP_NAME=<the name of the webapp>
GROUP_NAME=<the name of the resource group>
CUSTOM_DOMAIN=<the custom domain>
az group deployment create -g $GROUP_NAME --parameters webAppName=$WEBAPP_NAME customDomain=$CUSTOM_DOMAIN certificateName="$CERTIFICATE_NAME" --template-file customdomainssl.json
