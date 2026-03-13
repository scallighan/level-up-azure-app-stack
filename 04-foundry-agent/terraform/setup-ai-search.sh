#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

az login --identity --client-id "$AZURE_CLIENT_ID" >/dev/null

AI_SEARCH_NAME=$(terraform -chdir="${SCRIPT_DIR}" output -raw ai_search_endpoint)
AI_FOUNDRY_NAME=$(terraform -chdir="${SCRIPT_DIR}" output -raw ai_foundry_name)
STORAGE_ACCOUNT_RESOURCE_ID=$(terraform -chdir="${SCRIPT_DIR}" output -raw storage_account_resource_id)
ACCESS_TOKEN="$(az account get-access-token --resource https://search.azure.com --query accessToken -o tsv)"

DATASOURCE_NAME="ai-search-drinks-datasource"
INDEX_NAME="ai-search-drinks-index"
EMBEDDING_DEPLOYMENT_NAME="text-embedding-3-small"
EMBEDDING_MODEL_NAME="text-embedding-3-small"
EMBEDDING_DIMENSIONS=1536
OPENAI_RESOURCE_URI="https://${AI_FOUNDRY_NAME}.openai.azure.com"
DATASOURCE_URL="https://${AI_SEARCH_NAME}.search.windows.net/datasources/${DATASOURCE_NAME}?api-version=2025-05-01-preview"
INDEX_URL="https://${AI_SEARCH_NAME}.search.windows.net/indexes/${INDEX_NAME}?api-version=2025-09-01&allowIndexDowntime=true"

put_search_resource() {
    local label="$1"
    local url="$2"
    local payload="$3"

    echo "Applying ${label}:"
    echo "${payload}" | jq .

    curl --fail-with-body -sS -X PUT \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer ${ACCESS_TOKEN}" \
        --data "${payload}" \
        "${url}"

    echo
}

DATASOURCE_JSON=$(jq -n \
    --arg datasource_name "${DATASOURCE_NAME}" \
    --arg resource_id "${STORAGE_ACCOUNT_RESOURCE_ID}" \
    '{
        name: $datasource_name,
        type: "azureblob",
        container: {
            name: "search-indexing"
        },
        credentials: {
            connectionString: ("ResourceId=" + $resource_id + ";")
        }
    }')

INDEX_JSON=$(jq -n \
    --arg index_name "${INDEX_NAME}" \
    --arg openai_resource_uri "${OPENAI_RESOURCE_URI}" \
    --arg embedding_deployment_name "${EMBEDDING_DEPLOYMENT_NAME}" \
    --arg embedding_model_name "${EMBEDDING_MODEL_NAME}" \
    --argjson embedding_dimensions "${EMBEDDING_DIMENSIONS}" \
    '{
        name: $index_name,
        fields: [
            {
                name: "id",
                type: "Edm.String",
                key: true,
                filterable: true,
                retrievable: true
            },
            {
                name: "title",
                type: "Edm.String",
                searchable: true,
                retrievable: true
            },
            {
                name: "content",
                type: "Edm.String",
                searchable: true,
                retrievable: true
            },
            {
                name: "contentVector",
                type: "Collection(Edm.Single)",
                searchable: true,
                retrievable: false,
                stored: false,
                dimensions: $embedding_dimensions,
                vectorSearchProfile: "content-vector-profile"
            }
        ],
        vectorSearch: {
            algorithms: [
                {
                    name: "content-vector-hnsw",
                    kind: "hnsw",
                    hnswParameters: {
                        m: 4,
                        efConstruction: 400,
                        efSearch: 500,
                        metric: "cosine"
                    }
                }
            ],
            profiles: [
                {
                    name: "content-vector-profile",
                    algorithm: "content-vector-hnsw",
                    vectorizer: "content-vectorizer"
                }
            ],
            vectorizers: [
                {
                    name: "content-vectorizer",
                    kind: "azureOpenAI",
                    azureOpenAIParameters: {
                        resourceUri: $openai_resource_uri,
                        deploymentId: $embedding_deployment_name,
                        modelName: $embedding_model_name
                    }
                }
            ]
        }
    }')

put_search_resource "datasource ${DATASOURCE_NAME}" "${DATASOURCE_URL}" "${DATASOURCE_JSON}"
put_search_resource "index ${INDEX_NAME}" "${INDEX_URL}" "${INDEX_JSON}"
