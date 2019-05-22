#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# -e: immediately exit if any command has a non-zero exit status
# -o: prevents errors in a pipeline from being masked
# IFS new value is less likely to cause confusing bugs when looping arrays or arguments (e.g. $@)

usage() { echo "Usage: $0 -i <subscriptionId> -g <resourceGroupName> -n <deploymentName> -l <resourceGroupLocation> -m <imageName> -o <vaultResourceGroup> -p <vaultName> -q <databaseServerName> -r <databaseName> -s <servicePlanName> -w <sitesName> -t <redisName> -v <environmentName> -b <branch> -c <registryUsername>" 1>&2; exit 1; }

source common.sh

declare subscriptionId=""
declare resourceGroupName=""
declare deploymentName=""
declare resourceGroupLocation=""
declare imageName=""
declare vaultResourceGroup=""
declare vaultName=""
declare databaseServerName=""
declare databaseName=""
declare servicePlanName=""
declare sitesName=""
declare redisName=""
declare environmentName=""
declare branch=""
declare registryUsername=""

# Initialize parameters specified from command line
while getopts ":i:g:n:l:m:o:p:q:r:s:w:t:v:b:c:" arg; do
	case "${arg}" in
		i)
			subscriptionId=${OPTARG}
			;;
		g)
			resourceGroupName=${OPTARG}
			;;
		n)
			deploymentName=${OPTARG}
			;;
		l)
			resourceGroupLocation=${OPTARG}
			;;
                m)
                        imageName=${OPTARG}
                        ;;
                o)
                        vaultResourceGroup=${OPTARG}
                        ;;
                p)
                        vaultName=${OPTARG}
                        ;;
                q)
                        databaseServerName=${OPTARG}
                        ;;
                r) 
                        databaseName=${OPTARG}
                        ;;
                s)
                        servicePlanName=${OPTARG}
                        ;;
                w)     
                        sitesName=${OPTARG}
                        ;;
                t)
                        redisName=${OPTARG}
                        ;;
                v)
                        environmentName=${OPTARG}
                        ;;
                b)
                        branch=${OPTARG}
                        ;;
                c) 
                        registryUsername=${OPTARG}
                        ;;
		esac
done
shift $((OPTIND-1))

#Prompt for parameters is some required parameters are missing
if [[ -z "$subscriptionId" ]]; then
	echo "Your subscription ID can be looked up with the CLI using: az account show --out json "
	echo "Enter your subscription ID:"
	read subscriptionId
	[[ "${subscriptionId:?}" ]]
fi

if [[ -z "$resourceGroupName" ]]; then
	echo "This script will look for an existing resource group, otherwise a new one will be created "
	echo "You can create new resource groups with the CLI using: az group create "
	echo "Enter a resource group name"
	read resourceGroupName
	[[ "${resourceGroupName:?}" ]]
fi

if [[ -z "$deploymentName" ]]; then
	echo "Enter a name for this deployment:"
	read deploymentName
fi

if [[ -z "$resourceGroupLocation" ]]; then
	echo "If creating a *new* resource group, you need to set a location "
	echo "You can lookup locations with the CLI using: az account list-locations "
	
	echo "Enter resource group location:"
	read resourceGroupLocation
fi

if [[ -z "$imageName" ]]; then
        echo "Enter a name for the image name:"
        read imageName
fi

if [[ -z "$vaultResourceGroup" ]]; then
        echo "Enter the name of the (already existing) vault resource group:"
        read vaultResourceGroup
fi

if [[ -z "$vaultName" ]]; then
        echo "Enter the name of the (already existing) vault:"
        read vaultName
fi

if [[ -z "$databaseServerName" ]]; then
        echo "Enter a name for the database server:"
        read databaseServerName
fi

if [[ -z "$databaseName" ]]; then
        echo "Enter a name for the database:"
        read databaseName
fi

if [[ -z "$servicePlanName" ]]; then
        echo "Enter a name for the service plan:"
        read servicePlanName
fi

if [[ -z "$sitesName" ]]; then
        echo "Enter a name for the School Experience web site:"
        read sitesName
fi

if [[ -z "$redisName" ]]; then
        echo "Enter a name for the Redis instance (will be result in a hostname <name>.redis.cache.windows.net):"
        read redisName
fi

if [[ -z "$environmentName" ]]; then
        echo "Enter a value for the environment name ('dev', 'staging' or 'prod'):"
        read environmentName
fi

#parameter file path
parametersFilePath="parameters.json"

echo
if [ ! -f "$parametersFilePath" ]; then
	echo "$parametersFilePath not supplied, this can be useful when (re)creating non development environments..."
else
        echo "Using $parametersFilePath for additional parameter values"
        parametersFileString="@${parametersFilePath}"
fi

if [ -z "$subscriptionId" ] || [ -z "$resourceGroupName" ] || [ -z "$deploymentName" ]; then
	echo "Either one of subscriptionId, resourceGroupName, deploymentName is empty"
	usage
fi

if [[ -z "$branch" ]]; then
        echo "Enter a value for the branch:"
        read branch
fi

if [[ -z "$registryUsername" ]]; then
        echo "Enter a value for the registry username:"
        read registryUsername
fi

#login to azure using your credentials
az account show 1> /dev/null

if [ $? != 0 ];
then
	az login
fi

#set the default subscription id
az account set --subscription $subscriptionId

##################################################
#RESOURCE GROUP CREATION
##################################################
echo 
set +e
#Check for existing RG
az group show --name $resourceGroupName 1> /dev/null

if [ $? != 0 ]; then
	echo "Resource group with name $resourceGroupName could not be found. Creating new resource group to hold website, db, redis."
	set -e
	(
		set -x
		az group create --name $resourceGroupName --location $resourceGroupLocation 1> /dev/null
	)
	else
	echo "Using existing resource group to hold website, db amnd redis ..."
fi

##################################################
#VAULT RESOURCE GROUP CREATION
##################################################
echo
set +e
#Check for existing Vault RG
az group show --name $vaultResourceGroup 1> /dev/null

if [ $? != 0 ]; then
        echo "Resource group with name $vaultResourceGroup could not be found. Creating new resource group to hold Key Vault.."
        set -e
        (       
                set -x
                az group create --name $vaultResourceGroup --location $resourceGroupLocation 1> /dev/null
        )
        else
        echo "Using existing resource group to hold Key Vault..."
fi

####################################################
#VAULT CREATION
####################################################
echo 
set +e
az keyvault show -g $vaultResourceGroup -n $vaultName 1> /dev/null

if [ $? != 0 ]; then
        echo "Vault with name $vaultName could not be found. Creating new Vault.."
        set -e
        (
                set -x
                az keyvault create \
                  --name $vaultName \
                  --resource-group $vaultResourceGroup \
                  --location $resourceGroupLocation \
                  --enabled-for-template-deployment true 1> /dev/null
                set +x

                read -s -p "Enter value for DfE Signin Secret (set to 'rubbish' if not supplied)?" dfeSigninSecret
                echo 
                read -s -p "Enter value for Sentry DSN Secret (set to 'rubbish' if not supplied)?" sentryDsn
                echo 
                read -s -p "Enter value for Slack webhook Secret (set to 'rubbish' if not supplied)?" slackWebhook
                echo
                read -s -p "Enter value for Docker registry password Secret (set to 'rubbish' if not supplied)?" registryPassword
                echo
                setsecret dfeSigninSecret $vaultName ${dfeSigninSecret:-rubbish} 
                setsecret postgresAdminPassword $vaultName $(randomstring 16)
                setsecret postgresUserPassword $vaultName $(randomstring 16) 
                setsecret sentryDsn $vaultName ${sentryDsn:-rubbish}
                setsecret slackWebhook $vaultName ${slackWebhook:-rubbish}
                setsecret registryPassword $vaultName ${registryPassword:-rubbish}
        )
        else
        echo "Using existing Vault..."
fi

set -e
#####################################################
#DOCKER COMPOSE FILE CREATION
#####################################################
IMAGE_NAME=$imageName
IMAGE_TAG=latest
REGISTRY_USERNAME=$registryUsername
REGISTRY_HOST="registry-1.docker.io"

cat <<EOF > compose-school-experience.yml
version: '3.3'

services:
   school-experience:
     image: ${REGISTRY_HOST}/${IMAGE_NAME}:${IMAGE_TAG}
     ports:
       - "3000:3000"
     restart: always
     healthcheck:
       disable: true

   delayed-jobs:
     image: ${REGISTRY_HOST}/${IMAGE_NAME}:${IMAGE_TAG}
     command: rake jobs:work
     restart: always
     healthcheck:
       disable: true
EOF
echo "Using the following compose file..."
cat compose-school-experience.yml

sleep 10

####################################################
#START DEPLOYMENT
####################################################

export DATABASE_NAME=$databaseName
VAULT_NAME_LOWER_CASE="$(echo $vaultName | tr '[:upper:]' '[:lower:]')"

echo "Starting deployment..."
(
	set -x
	az group deployment create --name ${deploymentName} \
                                   --resource-group ${resourceGroupName} \
                                   --template-uri https://raw.githubusercontent.com/DFE-Digital/school-experience-devops/${branch}/template.json \
                                   --parameters ${parametersFileString:-} dockerComposeFile=@compose-school-experience.yml  databases_school_experience_name=${DATABASE_NAME} servers_db_name=${databaseServerName} vaultName=${vaultName} vaultResourceGroupName=${vaultResourceGroup} serverfarms_serviceplan_name=${servicePlanName} sites_school_experience_name=${sitesName} redis_name=${redisName} environmentName=${environmentName} _artifactsLocation=https://raw.githubusercontent.com/DFE-Digital/school-experience-devops/${branch}/ servers_db_createMode=Default
)

if [ $?  == 0 ];
 then
	echo "Template has been successfully deployed"
fi

rm compose-school-experience.yml

####################################################
#SET UP DATABASE
####################################################

postgresAdminPassword=$(az keyvault secret show --id https://${VAULT_NAME_LOWER_CASE}.vault.azure.net/secrets/postgresAdminPassword -o tsv --query value)
export postgresUserPassword=$(az keyvault secret show --id https://${VAULT_NAME_LOWER_CASE}.vault.azure.net/secrets/postgresUserPassword -o tsv --query value)
export dbuser=railsappuser

PGPASSWORD=$postgresAdminPassword psql -U adminuser@"${databaseServerName}" -h "${databaseServerName}".postgres.database.azure.com postgres -f createdb.sql

####################################################
#BOOTSTRAP IMAGE
####################################################

REGISTRY_PASSWORD=$(az keyvault secret show --id https://${VAULT_NAME_LOWER_CASE}.vault.azure.net/secrets/registryPassword -o tsv --query value)

if [ -n "${BUILD_APP+set}" ]; then
  git clone https://github.com/DFE-Digital/schools-experience.git /tmp/schools-experience
  cd /tmp/schools-experience
  docker build -f Dockerfile -t $REGISTRY_HOST/$IMAGE_NAME:$IMAGE_TAG .

  echo 'RUNNING  db:migrate db:seed'
  docker run -e RAILS_ENV=production -e DB_HOST="${databaseServerName}.postgres.database.azure.com"  -e DB_DATABASE=${DATABASE_NAME} -e DB_USERNAME="${dbuser}@${databaseServerName}" -e DB_PASSWORD=$postgresUserPassword -e SECRET_KEY_BASE=stubbed -e SKIP_REDIS=true --rm $REGISTRY_HOST/$IMAGE_NAME:$IMAGE_TAG rails db:migrate db:seed

  docker login $REGISTRY_HOST -u $REGISTRY_USERNAME -p $REGISTRY_PASSWORD
  docker push $REGISTRY_HOST/$IMAGE_NAME:$IMAGE_TAG
  rm -rf /tmp/schools-experience
fi

