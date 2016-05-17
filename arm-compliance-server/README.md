# Creating a Chef Compliance Server using an ARM template

<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fchef-partners%2Farm-templates%2Fmaster%2Farm-compliance-server%2Fcomplianceserver.json" target="_blank"><img src="http://azuredeploy.net/deploybutton.png"/></a>
<a href="http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fchef-partners%2Farm-templates%2Fmaster%2Farm-compliance-server%2Fcomplianceserver.json" target="_blank">
    <img src="http://armviz.io/visualizebutton.png"/>
</a>

This template will create a Compliance server in the specified resource group.  Cloud init is configured to set the FQDN of the machine for the Chef server using data that is passed in via the template.  This means that unlike previous versions of this repo a Custom script is not longer required.

## Parameters

The following table describes what each parameter is used for and any that have default values.

| Name           | Description                                                                                                           | Default Value | Example            |
|:---------------|:----------------------------------------------------------------------------------------------------------------------|:--------------|:-------------------|
| vmName         | Name of the virtual machine                                                                                           |               | chef-compliance-01 |
| adminUsername  | SSH username for the server                                                                                           | azure         |                    |
| adminPassword  | Password for the admin user                                                                                           |               |                    |
| dnsLabelPrefix | Name that will be assigned to the DNS to make an FQDN for the machine. Typically this would be the same as the vmName |               | chef-compliance-01 |
| chefServerSKU  | Name of the Chef Server SKU to use.                                                                                   | chefbyol      |                    |

Any of the parameters that have a default value do not appear in the `chefserver.parameters.json` file.  However to override the values add them to this file as required.

The template has been updated so that it can be used as a shared template in other ARM templates.  This makes it much easier to reuse the template without having to define it each time in other more complex templates.  The following parameters can be set and are intended to be specified when the template is part of a larger one.

| Name                        | Description                                                  | Default Value     |
|:----------------------------|:-------------------------------------------------------------|:------------------|
| vmSize                      | Size of VM to build within Azure                             | Standard_D1       |
| virtualNetworkName          | Name of the virtual network to create in the resource group  | chefNetwork       |
| addressPrefix               | Network range of the virtual network                         | 10.0.0.0/24       |
| subnetName                  | Name of the subnet to create within the virtual network      | chefSubnet        |
| subnetPrefix                | Address range for the new subnet                             | 10.0.0.0/28       |
| storageAccountName          | Name of the storage account to create                        | &lt;SEE BELOW&gt; |
| storageAccountType          | Type of storage account to use                               | Standard_LRS      |
| storageAccountContainerName | Name of the container in which the hard disks will be stored | vhds              |
| storageAccountMode          | Whether the stoarge account should be created or exists      | new               |
| virtualNetworksMode         | Whether the virtual network should be created or not         | new               |
| baseUrl                     | Base URL for the templates for the chef server               |                   |


## Run the template into Azure

There are two ways of running this in

### Option 1: Azure XPlat Command Line Tools

There are a few commands that are required to successfully deploy a template into Azure.

_Create the Resource group_

Unless an existing group is to be used to deploy the chef server to, an new one needs to be created.

```
$> azure group create "<NAME_OF_RESOURCE_GROUP>" -l "<AZURE_LOCATION>"
```

_Deploy the template to the resource group_

Once the group is available then the template can be deployed:

```
$> azure group deployment create -f chefserver.json -e chefserver.parameters.json <NAME_OF_RESOURCE_GROUP> <NAME_OF_DEPLOYMENT>
```

Once the task completes a new machine will exist in Azure.

### Option 2: PowerShell commands

If using Windows then the PowerShell commands for Azure can be used.

**Ensure that the Azure PowerShell package is installed - https://azure.microsoft.com/en-gb/documentation/articles/powershell-install-configure/**

_Create the Resource group_

Unless an existing group is to be used to deploy the chef server to, an new one needs to be created.

```
C:\> New-AzureRmResourceGroup -Name "<NAME_OF_RESOURCE_GROUP>" -Location "<AZURE_LOCATION>"
```

_Deploy the template to the resource group_

Once the group is available then the template can be deployed:

```
C:\> New-AzureRmResoureGroupDeployment -ResourceGroupName "<NAME_OF_RESOURCE_GROUP>" -TemplateFile chefserver.json -TemplateParameterFile chefserver.parameters.json -Name "<NAME_OF_DEPLOYMENT>"
```

## After Provision Steps

Once the server has been provisioned, the configured outputs will be displayed.  These outputs are as shown below:

| Name                     | Description                                                                                                             |
|:-------------------------|:------------------------------------------------------------------------------------------------------------------------|
| fqdn                     | The fully qualified domain name of the server.  This will be of the form <dnsLabelPrefix>.<location>.cloudapp.azure.com |
| sshCommand               | The ssh command required to login to the server with the correct user                                                   |
| complianceServerSetupUrl | The URL that is to be used to setup and verify that the server is being configured                                      |

![ARM Template Outputs](/arm-chef-server/images/outputs.png)

Once the server has built go to the url as specified in the `chefServerSignUpUrl` and enter the name of the virtual machine into the form.  This is so that there the system can be sure that it is being configured by the same person that built it.  After signup the system will redirect to the login page where a new account can be created.

For more information about using the Azure Marketplace chef server please refer to https://docs.chef.io/azure_portal.html.

Note:  After the configuration it maybe necessary to restart the chef server using `chef-server-ctl restart`
