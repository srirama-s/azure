#!/bin/bash
set -euo pipefail
IFS=$'\n\t'

# -e: immediately exit if any command has a non-zero exit status
# -o: prevents errors in a pipeline from being masked
# IFS new value is less likely to cause confusing bugs when looping arrays or arguments (e.g. $@)

usage() { echo "Usage: $0 -i <subscriptionId> -g <resourceGroupName> -n <deploymentName> -l <resourceGroupLocation> -u <deploymentuser> -p <deploymentpass>" 1>&2; exit 1; }

declare subscriptionId="1f193341-e1fd-4379-b639-c645bcc85cf0"
declare resourceGroupName="LinuxRG"
declare deploymentName="linuxphpapp"
declare deploymentuser="mywebappphpusr"
declare deploymentpass="mywebappphpu5r"
declare resourceGroupLocation="eastus"
declare appsvcplan="appsvc-linuxphpapp"

# Initialize parameters specified from command line
while getopts ":i:g:n:l:u:p" arg; do
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
		u)
			deploymentuser=${OPTARG}
			;;
		p)
			deploymentpass=${OPTARG}
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

if [[ -z "$deploymentuser" ]]; then
	echo "Enter a user name for this deployment:"
	read deploymentuser
fi

if [[ -z "$deploymentpass" ]]; then
	echo "Enter a password for this deployment user:"
	read deploymentpass
fi

if [[ -z "$resourceGroupLocation" ]]; then
	echo "If creating a *new* resource group, you need to set a location "
	echo "You can lookup locations with the CLI using: az account list-locations "
	
	echo "Enter resource group location:"
	read resourceGroupLocation
fi

#templateFile Path - template file to be used
templateFilePath="azure-webapp-php.json"

if [ ! -f "$templateFilePath" ]; then
	echo "$templateFilePath not found"
	exit 1
fi

#parameter file path
#parametersFilePath="params-linux.json"

#if [ ! -f "$parametersFilePath" ]; then
#	echo "$parametersFilePath not found"
#	exit 1
#fi

if [ -z "$subscriptionId" ] || [ -z "$resourceGroupName" ] || [ -z "$deploymentName" ] || [ -z "$deploymentuser" ] || [ -z "$deploymentpass" ]; then
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
	echo "Using resource group $resourceGroupName for deployment ..."
fi

#Creating deployment user
echo "Creating webapp deployment user..."
set -x
az webapp deployment user set --user-name $deploymentuser --password $deploymentpass 1>/dev/null

if [ $? != 0 ]; then
	echo "Deployment user is either not unique or cannot be created"
	echo "Deployment failed. Exiting !!"
	exit 1
else
	echo "Deployment user $deploymentuser is successfully created..."
fi

echo "Creating AppService plan..."
set -x
az appservice plan create --name $appsvcplan --resource-group $resourceGroupName --sku Free 1>/dev/null

if [ $? != 0 ]; then
	echo "Unable to create AppService plan. Check error details..."
	echo "Deployment failed. Exiting !!"
	exit 1
else
	echo "AppService plan $appsvcplan is successfully created..."
fi

#Start deployment
echo "Starting deployment..."
set -x
az webapp create --name "$deploymentName" --resource-group "$resourceGroupName" --plan "$appsvcplan" --runtime "PHP|7.0" --deployment-local-git 1>/dev/null

if [ $?  == 0 ];
 then
	echo "Deployment completed successfully"
fi
