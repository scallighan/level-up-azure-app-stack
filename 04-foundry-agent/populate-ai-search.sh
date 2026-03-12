#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_FILE="${DATA_FILE:-${SCRIPT_DIR}/data/drinks.txt}"
INDEX_NAME="${INDEX_NAME:-drinks-index}"
API_VERSION="${API_VERSION:-2025-09-01}"
RECREATE_INDEX="${RECREATE_INDEX:-false}"
SEARCH_ENDPOINT="${SEARCH_ENDPOINT:-}"
SEARCH_SERVICE_NAME="${SEARCH_SERVICE_NAME:-}"

require_command() {
	if ! command -v "$1" >/dev/null 2>&1; then
		echo "Missing required command: $1" >&2
		exit 1
	fi
}

usage() {
	cat <<'EOF'
Usage:
	SEARCH_SERVICE_NAME=my-search-service ./populate-ai-search.sh

Environment variables:
	SEARCH_SERVICE_NAME  Azure AI Search service name.
	SEARCH_ENDPOINT      Full search endpoint, for example https://my-search.search.windows.net.
	INDEX_NAME           Optional index name. Defaults to drinks-index.
	DATA_FILE            Optional path to the drinks data file.
	API_VERSION          Optional Search REST API version. Defaults to 2025-09-01.
	RECREATE_INDEX       Set to true to delete the index before recreating it.

Authentication:
	If SEARCH_API_KEY is not set, run az login first and ensure your identity has
	Search Service Contributor and Search Index Data Contributor on the search service.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	usage
	exit 0
fi

require_command jq
require_command curl

if [[ -z "${SEARCH_ENDPOINT}" ]]; then
	if [[ -z "${SEARCH_SERVICE_NAME}" ]]; then
		echo "Set SEARCH_SERVICE_NAME or SEARCH_ENDPOINT before running this script." >&2
		exit 1
	fi

	SEARCH_ENDPOINT="https://${SEARCH_SERVICE_NAME}.search.windows.net"
fi

SEARCH_ENDPOINT="${SEARCH_ENDPOINT%/}"

if [[ ! -f "${DATA_FILE}" ]]; then
	echo "Data file not found: ${DATA_FILE}" >&2
	exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

INDEX_SCHEMA_FILE="${TMP_DIR}/index.json"
DOCUMENTS_FILE="${TMP_DIR}/documents.json"
NORMALIZED_DATA_FILE="${TMP_DIR}/drinks.json"

sed 's/\\\$/\$/g' "${DATA_FILE}" > "${NORMALIZED_DATA_FILE}"

jq empty "${NORMALIZED_DATA_FILE}" >/dev/null

cat > "${INDEX_SCHEMA_FILE}" <<EOF
{
	"name": "${INDEX_NAME}",
	"fields": [
		{
			"name": "id",
			"type": "Edm.String",
			"key": true,
			"searchable": false,
			"filterable": true,
			"sortable": true,
			"facetable": false,
			"retrievable": true
		},
		{
			"name": "name",
			"type": "Edm.String",
			"searchable": true,
			"filterable": true,
			"sortable": true,
			"facetable": false,
			"retrievable": true
		},
		{
			"name": "description",
			"type": "Edm.String",
			"searchable": true,
			"retrievable": true
		},
		{
			"name": "ingredients",
			"type": "Collection(Edm.String)",
			"searchable": true,
			"retrievable": true
		},
		{
			"name": "price",
			"type": "Edm.String",
			"searchable": true,
			"filterable": true,
			"sortable": true,
			"retrievable": true
		},
		{
			"name": "priceValue",
			"type": "Edm.Double",
			"filterable": true,
			"sortable": true,
			"facetable": true,
			"retrievable": true
		},
		{
			"name": "rating",
			"type": "Edm.Int32",
			"filterable": true,
			"sortable": true,
			"facetable": true,
			"retrievable": true
		},
		{
			"name": "searchableText",
			"type": "Edm.String",
			"searchable": true,
			"retrievable": false
		}
	]
}
EOF

jq '{value: [ .[] | {
	"@search.action": "mergeOrUpload",
	id: (.name | ascii_downcase | gsub("[^a-z0-9]+"; "-") | gsub("(^-|-$)"; "")),
	name,
	description,
	ingredients,
	price,
	priceValue: (.price | sub("^\\$"; "") | tonumber),
	rating,
	searchableText: ([.name, .description, (.ingredients | join(" ")), .price, ("rating " + (.rating | tostring))] | join(" "))
}]}' "${NORMALIZED_DATA_FILE}" > "${DOCUMENTS_FILE}"

auth_header() {
    az login --identity --client-id $AZURE_CLIENT_ID
	local access_token
	access_token="$(az account get-access-token --resource https://search.azure.com --query accessToken -o tsv)"
	printf 'Authorization: Bearer %s' "${access_token}"
}

AUTH_HEADER="$(auth_header)"

send_request() {
	local method="$1"
	local url="$2"
	local body_file="${3:-}"
	local response_file
	local status_code

	response_file="${TMP_DIR}/response.json"

	if [[ -n "${body_file}" ]]; then
		status_code="$(curl -sS -o "${response_file}" -w '%{http_code}' \
			-X "${method}" \
			-H "Content-Type: application/json" \
			-H "${AUTH_HEADER}" \
			--data @"${body_file}" \
			"${url}")"
	else
		status_code="$(curl -sS -o "${response_file}" -w '%{http_code}' \
			-X "${method}" \
			-H "Content-Type: application/json" \
			-H "${AUTH_HEADER}" \
			"${url}")"
	fi

	if [[ ! "${status_code}" =~ ^2 ]]; then
		echo "Request failed: ${method} ${url}" >&2
		echo "HTTP ${status_code}" >&2
		cat "${response_file}" >&2
		exit 1
	fi
}

if [[ "${RECREATE_INDEX}" == "true" ]]; then
	delete_status="$(curl -sS -o /dev/null -w '%{http_code}' \
		-X DELETE \
		-H "Content-Type: application/json" \
		-H "${AUTH_HEADER}" \
		"${SEARCH_ENDPOINT}/indexes/${INDEX_NAME}?api-version=${API_VERSION}")"

	if [[ "${delete_status}" != "204" && "${delete_status}" != "404" ]]; then
		echo "Failed to delete existing index ${INDEX_NAME}. HTTP ${delete_status}" >&2
		exit 1
	fi
fi

echo "Creating or updating index ${INDEX_NAME} on ${SEARCH_ENDPOINT}"
send_request \
	PUT \
	"${SEARCH_ENDPOINT}/indexes/${INDEX_NAME}?api-version=${API_VERSION}" \
	"${INDEX_SCHEMA_FILE}"

document_count="$(jq '.value | length' "${DOCUMENTS_FILE}")"
echo "Uploading ${document_count} drinks to index ${INDEX_NAME}"
send_request \
	POST \
	"${SEARCH_ENDPOINT}/indexes/${INDEX_NAME}/docs/index?api-version=${API_VERSION}" \
	"${DOCUMENTS_FILE}"

echo "Azure AI Search index ${INDEX_NAME} is ready."
