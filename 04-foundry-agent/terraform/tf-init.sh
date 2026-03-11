#!/bin/bash

az login --identity --client-id $AZURE_CLIENT_ID
temp_key=$(basename "$(dirname "$PWD")")
export TF_VAR_key="${temp_key}.tfstate"
echo $TF_VAR_key
envsubst < backend.tfvars.tmpl > backend.tfvars

terraform init --backend-config=backend.tfvars