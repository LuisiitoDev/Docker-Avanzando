#!/bin/bash

set -e

RESOURCE_GROUP="rickandmorty-rg"
LOCATION="eastus2"
ACR_NAME="rickandmortyacr$RANDOM"
ENVIRONMENT_NAME="rickandmorty-env"
CONTAINER_APP_NAME="rickandmorty-app"
LOCAL_IMAGE_NAME="rickandmorty:latest"

echo -e "Creating resource group: $RESOURCE_GROUP in $LOCATION"
az group create --name $RESOURCE_GROUP --location $LOCATION --output none

echo -e "Creating Azure Container Registry: $ACR_NAME"
az acr create \
    --resource-group $RESOURCE_GROUP \
    --name $ACR_NAME \
    --sku Basic \
    --admin-enabled true \
    --output none

echo -e "Logging in to Azure Container Registry: $ACR_NAME"
az acr login --name $ACR_NAME


docker build --platform linux/amd64 -t $LOCAL_IMAGE_NAME .
echo -e "Tagging local image: $LOCAL_IMAGE_NAME with ACR name: $ACR_NAME"
docker tag $LOCAL_IMAGE_NAME $ACR_NAME.azurecr.io/$LOCAL_IMAGE_NAME

echo -e "Pushing image to Azure Container Registry: $ACR_NAME"
docker push $ACR_NAME.azurecr.io/$LOCAL_IMAGE_NAME

echo -e "Ensuring Azure Container Apps extension is installed"
az extension add --name containerapp --upgrade --output none

echo "Creating Azure Container Apps environment: $ENVIRONMENT_NAME"
az containerapp env create \
    --name $ENVIRONMENT_NAME \
    --resource-group $RESOURCE_GROUP \
    --location $LOCATION \
    --output none

echo -e "Fetching ACR credentials for Azure Container Apps"
ACR_USERNAME=$(az acr credential show --name $ACR_NAME --query "username" -o tsv)
ACR_PASSWORD=$(az acr credential show --name $ACR_NAME --query "passwords[0].value" -o tsv)

echo -e "Deploying the container app: $CONTAINER_APP_NAME"

FQDN=$(az containerapp create \
    --name $CONTAINER_APP_NAME \
    --resource-group $RESOURCE_GROUP \
    --environment $ENVIRONMENT_NAME \
    --image $ACR_NAME.azurecr.io/$LOCAL_IMAGE_NAME \
    --registry-server $ACR_NAME.azurecr.io \
    --registry-username $ACR_USERNAME \
    --registry-password $ACR_PASSWORD \
    --target-port 80 \
    --ingress 'external' \
    --query properties.configuration.ingress.fqdn \
    --output tsv)

echo -e "Deployment successful. Your app is available at: https://$FQDN"