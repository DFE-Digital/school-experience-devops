# school-experience-devops

To completely bootstrap an environment including the building of the school-experience image, seeding the database and pushing of the locally built image to the registry...

Prerequisites:

There must a Azure Key Vault set up for which the account running the `deploy.sh` [has 'get' and 'list' access](https://docs.microsoft.com/en-us/azure/key-vault/quick-create-net#assign-permissions-to-your-application-to-read-secrets-from-key-vault). The key vault must have the following secrets

* `postgresAdminPassword`
* `postgresUserPassword`
* `slackWebhook` - required but will be ignored if slackEnv is set to '' 
* `sentryDsn`  - required but will be ignored if set to ''
* `dfeSigninSecret` - required nbu will be ignored if set to ''

**The deploy script uses the `--template-uri` i.e. remote templates. This is required because it references Azure Key Vaults's with via [dynamic ids](https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-manager-keyvault-parameter#reference-secrets-with-dynamic-id)** 

Usage: 

    BUILD_APP=true ./deploy.sh -i <subscriptionId> -g <resourceGroupName> -n <deploymentName> -l <resourceGroupLocation> -m <registryName> -o <vaultResourceGroup> -p <vaultName> -q <databaseServerName> -r <databaseName> -s <servicePlanName> -w <sitesName> -t <redisName> -v <environmentName> -b <branch of this repo>

Example:

    BUILD_APP=true ./deploy.sh -i XXXX-XXXX-XXXX-XXXX -g schoolExperienceGroupTest -n schoolExperienceDeployment -l uksouth -m schoolExperienceRegistryTest -o schoolExperienceVaultGroup -p schoolExperienceVault -q schoolexperience-db-test -r school_experience_test -s schoolExperienceServicePlanTest -w schoolexperience-test -t schoolexperience-redis-test -v dev -b master

To only do the ARM template deployment 

Usage:

    ./deploy.sh -i <subscriptionId> -g <resourceGroupName> -n <deploymentName> -l <resourceGroupLocation> -m <registryName> -o <vaultResourceGroup> -p <vaultName> -q <databaseServerName> -r <databaseName> -s <servicePlanName> -w <sitesName> -t <redisName> -v <environmentName> -b <branch of this repo>

## Custom Domains and SSL certificates

If a deployment requires a custom domain with an accompanying SSL certificate then

* The certificate must be uploaded to the Key Vault as a .pfx file 
* A parameter file must be provided to the `az group deployment` command (not supported when `az group deployment` is invoked via the `deploy.sh` shell script) which includes the following parameter.
```
    "customDomainsWithCerts": {
        "value": [
            {
                "certificateSecretName": "<the name that was used when uploading the .pfx file to the key vault>",
                "certificateName": "<the name that will be used for the certificate resource> ",
                "customDomain": "<the custom domain>" 
            }
        ]
    }
```
Note that `customDomainsWithCerts` is an array and so many custom domain plus certificate combinations can be defined.
