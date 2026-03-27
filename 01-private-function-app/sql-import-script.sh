serverName=$(terraform output -raw sql_server_name)
databaseName=$(terraform output -raw sql_database_name)
resourceGroupName=$(terraform output -raw resource_group_name)
storageUri=$(terraform output -raw bacpac_storage_uri)
managedIdentitySqlResourceId=$(terraform output -raw this_managed_identity_id)

echo "Importing bacpac to Azure SQL Database... $serverName, $databaseName, $resourceGroupName, $storageUri, $managedIdentitySqlResourceId"

az sql db import -s $serverName -n $databaseName -g $resourceGroupName --auth-type ManagedIdentity -u $managedIdentitySqlResourceId --storage-key-type ManagedIdentity --storage-key $managedIdentitySqlResourceId --storage-uri $storageUri