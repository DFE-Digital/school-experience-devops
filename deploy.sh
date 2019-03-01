#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# -e: immediately exit if any command has a non-zero exit status
# -o: prevents errors in a pipeline from being masked
# IFS new value is less likely to cause confusing bugs when looping arrays or arguments (e.g. $@)

usage() { echo "Usage: $0 -i <subscriptionId> -g <resourceGroupName> -n <deploymentName> -l <resourceGroupLocation>" 1>&2; exit 1; }

declare subscriptionId=""
declare resourceGroupName=""
declare deploymentName=""
declare resourceGroupLocation=""

# Initialize parameters specified from command line
while getopts ":i:g:n:l:" arg; do
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

#####################################################
#PARAMETER FILE SUBSTITUTIONS
#####################################################

export vaultGroup=schoolExperienceVaultGroup
export vaultName=schoolExperienceVault

sed -e "s/\${subscriptionId}/${subscriptionId}/" -e "s/\${vaultGroup}/${vaultGroup}/" -e "s/\${vaultName}/${vaultName}/" parameters.json.txt > parameters.json

echo "Using the following parameters file..."
cat parameters.json

#parameter file path
parametersFilePath="parameters.json"

if [ ! -f "$parametersFilePath" ]; then
	echo "$parametersFilePath not found"
	exit 1
fi

if [ -z "$subscriptionId" ] || [ -z "$resourceGroupName" ] || [ -z "$deploymentName" ]; then
	echo "Either one of subscriptionId, resourceGroupName, deploymentName is empty"
	usage
fi

#login to azure using your credentials
az account show 1> /dev/null

if [ $? != 0 ];
then
	az login
fi

#set the default subscription id
az account set --subscription $subscriptionId

set +e

#Check for existing RG
az group show --name $resourceGroupName 1> /dev/null

if [ $? != 0 ]; then
	echo "Resource group with name" $resourceGroupName "could not be found. Creating new resource group.."
	set -e
	(
		set -x
		az group create --name $resourceGroupName --location $resourceGroupLocation 1> /dev/null
	)
	else
	echo "Using existing resource group..."
fi

#####################################################
#DOCKER COMPOSE FILE CREATION
#####################################################

REGISTRY_NAME=schoolExperienceRegistryTest
REGISTRY_HOST="$(echo $REGISTRY_NAME | tr '[:upper:]' '[:lower:]').azurecr.io"
IMAGE_NAME=school-experience
IMAGE_TAG=latest

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

####################################################
#START DEPLOYMENT
####################################################

export DATABASE_NAME=school_experience_test
DATABASE_SERVER_NAME=schoolexperience-db-test
VAULT_NAME=schoolExperienceVault
VAULT_RESOURCE_GROUP_NAME=schoolExperienceVaultGroup 

echo "Starting deployment..."
(
	set -x
	az group deployment create --name "$deploymentName" \
                                   --resource-group "$resourceGroupName" \
                                   --template-uri https://raw.githubusercontent.com/DFE-Digital/school-experience-devops/master/template.json \
                                   --parameters "@${parametersFilePath}" dockerComposeFile=@compose-school-experience.yml registries_schoolExperienceRegistry_name=${REGISTRY_NAME} databases_school_experience_test_name=${DATABASE_NAME} servers_schoolexperience_dev_db_name=${DATABASE_SERVER_NAME} vaultName=${VAULT_NAME} vaultResourceGroupName=${VAULT_RESOURCE_GROUP_NAME}
)

if [ $?  == 0 ];
 then
	echo "Template has been successfully deployed"
fi

rm compose-school-experience.yml
rm "${parametersFilePath}"

####################################################
#SET UP DATABASE
####################################################

postgresAdminPassword=$(az keyvault secret show --id https://schoolexperiencevault.vault.azure.net/secrets/postgresAdminPassword -o tsv --query value)

PGPASSWORD=$postgresAdminPassword psql -U adminuser@"${DATABASE_SERVER_NAME}" -h "${DATABASE_SERVER_NAME}".postgres.database.azure.com postgres -f createdb.sql

####################################################
#BOOTSTRAP IMAGE
####################################################

REGISTRY_USER=$REGISTRY_NAME
REGISTRY_PASSWORD=$(az acr credential show -n $REGISTRY_NAME --output tsv --query passwords[0].value)

if [ "$BUILD_APP" = "true" ]; then
  git clone https://github.com/DFE-Digital/schools-experience.git /tmp/schools-experience
  cd /tmp/schools-experience
  docker build -f Dockerfile -t $REGISTRY_HOST/school-experience:latest .
  docker login $REGISTRY_HOST -u $REGISTRY_USER -p $REGISTRY_PASSWORD
  docker push $REGISTRY_HOST/school-experience:latest
  rm -rf /tmp/schools-experience
fi

