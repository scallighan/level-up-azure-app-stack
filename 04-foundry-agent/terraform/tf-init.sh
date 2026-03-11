#!/bin/bash

az login --identity --client-id $AZURE_CLIENT_ID

envsubst < backend.tfvars.tmpl > backend.tfvars

terraform init --backend-config=backend.tfvars