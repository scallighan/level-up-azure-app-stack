#!/bin/bash

az login --identity --client-id $AZURE_CLIENT_ID

AI_SEARCH_NAME=$(terraform output -raw ai_search_endpoint)
ENDPOINT_URL="https://${AI_SEARCH_NAME}.search.windows.net/datasources?api-version=2025-05-01-preview"
ACCESS_TOKEN="$(az account get-access-token --resource https://search.azure.com --query accessToken -o tsv)"
STORAGE_ACCOUNT_RESOURCE_ID=$(terraform output -raw storage_account_resource_id)
DATA_JSON_TEMPLATE='{"type": "azureblob", "container": { "name": "search-indexing" },"credentials": { "connectionString": "ResourceId=${STORAGE_ACCOUNT_RESOURCE_ID};"},"name": "ai-search-drinks-datasource"}'

# combine storage_account_resource_id into the data JSON template
DATA_JSON=$(echo "${DATA_JSON_TEMPLATE}" | jq --arg resource_id "${STORAGE_ACCOUNT_RESOURCE_ID}" '.credentials.connectionString = ("ResourceId=" + $resource_id + ";")')

echo "Using the following data JSON for the request:"
echo "${DATA_JSON}" | jq .

curl -vvv -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    --data "${DATA_JSON}" \
    "${ENDPOINT_URL}"
