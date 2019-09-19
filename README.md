# school-experience-devops

The following describes how to completely bootstrap an environment including the building of the school-experience image, seeding the database, pushing of the locally built image to the registry and the creation of a Azure Key Vault with secrets. The deployment script will generate secure passwords for the Postgres admin and user passwords and will prompt the user for the Sentry DSN, Slack webhook and DfE Signin secret value. If the user chooses not to supply values for the last three secrets then a value of `rubbish` is used for each of them.  

**The deploy script uses the `--template-uri` i.e. remote templates. This is required because it references Azure Key Vaults's via [dynamic ids](https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-manager-keyvault-parameter#reference-secrets-with-dynamic-id)** 

## Prerequisites

The user must have access to an Azure subscription with contributor privileges and also have [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest) installed on the machine where the scripts will be run.

## Running Deployment Script

Usage: 

    BUILD_APP=true ./deploy.sh -i <subscriptionId> -g <resourceGroupName> -n <deploymentName> -l <resourceGroupLocation> -m <imageName> -o <vaultResourceGroup> -p <vaultName> -q <databaseServerName> -r <databaseName> -s <servicePlanName> -w <sitesName> -t <redisName> -v <environmentName> -b <branch of this repo> 

Example (the reader should know their subscription id, registry username and the organisation being used for the private repo in docker hub):

    BUILD_APP=true ./deploy.sh -i XXXX-XXXX-XXXX-XXXX -g schoolExperienceGroupTest -n schoolExperienceDeployment -l uksouth -m <ORG>/school-experience -o seVaultGroupTest -p seVaultTest -q schoolexperience-db-test -r school_experience_test -s schoolExperienceServicePlanTest -w schoolexperience-test -t schoolexperience-redis-test -v dev -b master 

To only do the ARM template deployment:

    ./deploy.sh -i <subscriptionId> -g <resourceGroupName> -n <deploymentName> -l <resourceGroupLocation> -m <imageName> -o <vaultResourceGroup> -p <vaultName> -q <databaseServerName> -r <databaseName> -s <servicePlanName> -w <sitesName> -t <redisName> -v <environmentName> -b <branch of this repo> 

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

## Enabling Alerts

The ARM template for School Experience supports the creation of Azure Monitor alerts for the various server components. To enable the setting up of alerts make sure the `parameters.json` file contains something like
```
{
    "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "applyAlerts": {
            "value": true
        },
        "supportEmailAddresses": {
             "value": [
                  {
                      "name": "joe.bloggs",
                      "email": "joe.bloggs@grange.hill.co.uk"
                  }
             ]
        }
    }
}
```

## Old SEP Domains

A list of old SEP domains that if present will redirect traffic to a informational page, this assumes that relevant DNS records have been set up to point to the web application and that SSL certificates and custom domains have been configured (see previous section).


## Other Parameters

This is a **non-exhaustive** list of other parameters.

| Parameter Name | Description   | Default |
| -------------- | ------------- | ------- |
| `appSecureUsername`  | Enables basic auth for the web application if specified, ends up as the environment variable `SECURE_USERNAME`  | |
| `appSecurePassword`  | Enables basic auth for the web application is specified, ends up as the environment variable `SECURE_PASSWORD`  | |
| `applyPostgres`      | Whether to apply the PostgreSQL ARM template | `true` |
| `applyRedis`         | Whether to apply the Redis ARM template | `true` |
| `enableAppInsightsJavascript` | Whether to add the App Insights Javascript library to the page | `false`, though generally the app is deployed with a `true` setting |
| `phase` | The phase (i.e. what features) that app will run with, when left blank will use the default phase configured in the application code | |
| `applyServicePlan` | Whether to apply the Service Plan template | `true` |
| `applyBackend` | Whether to apply the backend (PostgreSQL, Redis) ARM template | `true` |
| `webTestEnabled` | Whether to enable the web test | `false` |
| `applyRedisFirewall` | Whether to apply the Redis firewall | `true` |
| `applyPostgresFirewall` | Whether to apply the PostgreSQL firewall | `true` |
| `addSupportWebhook` | Whether to add the webhook to the Azure support group | `false` |
| `deployToSlot` | Whether to deploy to a staging slot rather than the default produciton slot ( see https://docs.microsoft.com/en-us/azure/app-service/deploy-staging-slots) | `false` |
| `deploymentId` | An identifier that the application will return on the `/deployment.txt` endpoint, ends up as the environment variable `DEPLOYMENT_ID` | |
| `deploymentUsername` | The basic auth username that will be used for the `/deployment.txt` endpoint, ends up as the environment vairable `DEPLOYMENT_PASSWORD` | |

