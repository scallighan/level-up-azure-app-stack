cd terraform
source .env
export container_app_name=$(terraform output -raw container_app_name)
export resource_group_name=$(terraform output -raw resource_group_name)
echo "Connecting to Container App: ${container_app_name} in Resource Group: ${resource_group_name}"
az containerapp exec -n ${container_app_name} -g ${resource_group_name} --command /bin/bash