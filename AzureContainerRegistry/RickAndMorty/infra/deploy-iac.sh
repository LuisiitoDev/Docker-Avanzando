#!/usr/bin/env bash
set -euo pipefail

RESOURCE_GROUP="${RESOURCE_GROUP:-rickandmorty-iac-rg}"
LOCATION="${LOCATION:-eastus2}"
PREFIX="${PREFIX:-rickmorty}"
IMAGE_NAME="${IMAGE_NAME:-rickandmorty:latest}"
APP_PATH="${APP_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
INFRA_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none

az deployment group create \
  --name foundation \
  --resource-group "$RESOURCE_GROUP" \
  --template-file "$INFRA_PATH/foundation.bicep" \
  --parameters location="$LOCATION" prefix="$PREFIX" \
  --output none

ACR_NAME="$(az deployment group show --name foundation --resource-group "$RESOURCE_GROUP" --query properties.outputs.acrName.value --output tsv)"
ENVIRONMENT_NAME="$(az deployment group show --name foundation --resource-group "$RESOURCE_GROUP" --query properties.outputs.environmentName.value --output tsv)"
IDENTITY_NAME="$(az deployment group show --name foundation --resource-group "$RESOURCE_GROUP" --query properties.outputs.identityName.value --output tsv)"

az acr build \
  --registry "$ACR_NAME" \
  --image "$IMAGE_NAME" \
  "$APP_PATH"

APP_URL="$(az deployment group create \
  --name container-app \
  --resource-group "$RESOURCE_GROUP" \
  --template-file "$INFRA_PATH/app.bicep" \
  --parameters \
    location="$LOCATION" \
    acrName="$ACR_NAME" \
    environmentName="$ENVIRONMENT_NAME" \
    identityName="$IDENTITY_NAME" \
    imageName="$IMAGE_NAME" \
  --query properties.outputs.url.value \
  --output tsv)"

echo "Deployment completed: $APP_URL"
echo "Test endpoint: $APP_URL/weatherforecast"

