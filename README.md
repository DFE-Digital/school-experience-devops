# school-experience-devops

The following describes how to completely bootstrap an environment including the building of the school-experience image, seeding the database, pushing of the locally built image to the registry and the creation of a Azure Key Vault with secrets. The deployment script will generate secure passwords for the Postgres admin and user passwords and will prompt the user for the Sentry DSN, Slack webhook and DfE Signin secret value. If the user chooses not to supply values for the last three secrets then a value of `rubbish` is used for each of them.  

**The deploy script uses the `--template-uri` i.e. remote templates. This is required because it references Azure Key Vaults's via [dynamic ids](https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-manager-keyvault-parameter#reference-secrets-with-dynamic-id)** 

## Prerequisites

The user must have access to an Azure subscription with contributor privileges and also have [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest) installed on the machine where the scripts will be run.

## Running Deployment Script

Usage: 

    BUILD_APP=true ./deploy.sh -i <subscriptionId> -g <resourceGroupName> -n <deploymentName> -l <resourceGroupLocation> -m <registryName> -o <vaultResourceGroup> -p <vaultName> -q <databaseServerName> -r <databaseName> -s <servicePlanName> -w <sitesName> -t <redisName> -v <environmentName> -b <branch of this repo>

Example:

    BUILD_APP=true ./deploy.sh -i XXXX-XXXX-XXXX-XXXX -g schoolExperienceGroupTest -n schoolExperienceDeployment -l uksouth -m schoolExperienceRegistryTest -o seVaultGroupTest -p seVaultTest -q schoolexperience-db-test -r school_experience_test -s schoolExperienceServicePlanTest -w schoolexperience-test -t schoolexperience-redis-test -v dev -b master

To only do the ARM template deployment:

    ./deploy.sh -i <subscriptionId> -g <resourceGroupName> -n <deploymentName> -l <resourceGroupLocation> -m <registryName> -o <vaultResourceGroup> -p <vaultName> -q <databaseServerName> -r <databaseName> -s <servicePlanName> -w <sitesName> -t <redisName> -v <environmentName> -b <branch of this repo>

Additional parameters can be provided to the underlying Azure Resource Manager template by creating a `parameters.json` in the root of project.

## Custom Domains and SSL certificates

If a deployment requires a custom domain with an accompanying SSL certificate then

* The certificate must be uploaded to the Key Vault as a .pfx file 
* Create a `parameters.json` file in the root of the project with contents
```
{
    "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "customDomainsWithCerts": {
            "value": [
                {
                    "certificateSecretName": "<the name that was used when uploading the .pfx file to the key vault>",
                    "certificateName": "<the name that will be used for the certificate resource> ",
                    "customDomain": "<the custom domain>" 
                }
            ]
        }
    }
}
```
Note that `customDomainsWithCerts` is an array and so many custom domain plus certificate combinations can be defined.

An additional standalone template exists in the root folder of this project which also allows a custom domain / SSL certificate to be configured:

```
az group deployment create -g schoolExperienceGroup --parameters webAppName=<web app name> customDomain=<custom domain> certificateName=<certificate name and secret name> --template-file customdomainssl.json
```
