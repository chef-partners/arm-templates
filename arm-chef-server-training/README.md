# Creating a Chef Server using an ARM template

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fchef-partners%2Farm-templates%2Fmaster%2Farm-chef-server-training%2Fchef-compliance-training.json" target="_blank"><img src="http://azuredeploy.net/deploybutton.png"/></a>
<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fchef-partners%2Farm-templates%2Fmaster%2Farm-chef-server-training%2Fchef-compliance-training.json" target="_blank">
    <img src="http://armviz.io/visualizebutton.png"/>
</a>

This template is designed to be used for the Chef training demo.  It derives and defaults a number of parameters to make creation easier during the workshops.

*The template is not intended to be used for testing.  Please use the template [here](https://github.com/chef-partners/arm-templates/tree/master/arm-chef-server) for that purpose*

## Configurable parameters

There are only three configurable parameters with this template:

| Name          | Description                                                           | Example              |
|:--------------|:----------------------------------------------------------------------|:---------------------|
| vmName        | Name of the virtual machine.  This will also set the `dnsLabelPrefix` | {company}-chefserver |
| adminUsername | Name of the admin user to create                                      | azure                |
| adminPassword | Password to set for the specified user                                |                      |

Note:  Although there should be no need to log into the server using SSH, the username and password parameters have been left as definable items so that problems can be addressed.

## Defaulted parameters

To make the creation of the Chef Server as easy as possible the following parameters are defaulted during creation.  The following table shows what these parameters are and what the default values are.

*It is not possible to change these values*

| Attribute                     | Derived? | Defaulted? | Value / Comments                                                                         |
|:------------------------------|:---------|:-----------|:-----------------------------------------------------------------------------------------|
| dnsLabelPrefix                | true     |            | based on the vmName                                                                      |
| chefServerSKU                 |          | true       | chefbyol                                                                                 |
| vmSize                        |          | true       | Standard_A5                                                                              |
| virtualNetworkName            |          | true       | chefNetwork                                                                              |
| addressPrefix                 |          | true       | 10.0.0.0/24                                                                              |
| subnetName                    |          | true       | chefSubnet                                                                               |
| subnetPrefix                  |          | true       | 10.0.0.0/28                                                                              |
| storageAccountName            | true     |            | Based on the subscription_id, name of the resource group and the vmName                  |
| storageAccountType            |          | true       | Standard_LRS                                                                             |
| storageAccountContainerName   |          | true       | vhds                                                                                     |
| storageAccountMode            |          | true       | new - this states that a storage account must be created                                 |
| storageAccountTemplateBaseUrl |          | true       | https://raw.githubusercontent.com/chef-partners/arm-templates/master/arm-storage-account |
| virtualNetworkMode            |          | true       | new - this states that a virtual network must be created                                 |
| virtualNetworkTemplateBaseUrl |          | true       | https://raw.githubusercontent.com/chef-partners/arm-templates/master/arm-virtual-network |

The `storageAccountName` must be globally unique.  In this example it is based on your subscription_id, the name of the resource group that it is being added to and the specified `vmName` of the chef server.

## Outputs

There are three outputs from this template:

| Name                | Description                               | Example                                                      |
|:--------------------|:------------------------------------------|:-------------------------------------------------------------|
| fqdn                | The public FQDN of the chef server        | acme-chefserver.westeurope.cloudapp.azure.com                |
| sshCommand          | SSH Login command                         | ssh azure@acme-chefserver.westeurope.cloudapp.azure.com      |
| chefServerSignUpUrl | URL required to configure the Chef server | https://acme-chefserver.westeurope.cloudapp.azure.com/signup |

The above outputs will be based on the parameters that were set during the creation of the machine.
