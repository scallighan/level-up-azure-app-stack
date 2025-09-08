# 0 Prelab Work
In order to interact with a private environment we need to setup a basic vnet with a VM or container app to connect in. To save on costs, we will setup a container app as our compute.

## Resources
Create the following resources
* Resource Group
* Vnet
* Subnet
* NSG
* User Assigned Managed Identity
* Container App Environment
* Azure Container App

## Terraform

Change directory into the terraform folder for this lab
```
cd 0-prelab-work/terraform
```
Create a .env file 
```
cp env.sample .env
```

Edit the .env file with the information

Then source the .env file so we can use the environment variables and initialize terraform

```
source .env
terraform init
```
Apply the terraform code to create the lab.
```
terraform apply
```