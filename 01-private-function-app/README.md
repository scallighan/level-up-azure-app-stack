# 1 Private Function App
Create an Azure Function App and have it be privately accessible via private endpoints. Additionally, configure the function app to use a private storage account with a managed identity for access.

* Connect to the jumpbox ACA instance from the `00-prelab-work`
* `/levelup/level-up-azure-app-stack/01-private-function-app/terraform`
* `./tf-init.sh`
* `terraform apply`
* then CD up to `/levelup/level-up-azure-app-stack/01-private-function-app/` and run `sql-import-script.sh` (Note: this will take some time to complete the import)

