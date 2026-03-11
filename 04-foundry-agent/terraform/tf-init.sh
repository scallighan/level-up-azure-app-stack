#!/bin/bash

envsubst < backend.tfvars.tmpl > backend.tfvars

terraform init --backend-config=backend.tfvars