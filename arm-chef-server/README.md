# Creating a Chef Server using an ARM template

This template will create a Chef server in the specified resource group.  The software will be installed and configured according to the parameters that have been supplied.  This update means that no manual operations are required to get the Chef server up and running.

## Parameters

The following table describes what each parameter is used for and any that have default values.

| Name               | Description                                                                                                           | Default Value     | Example     |
|:-------------------|:----------------------------------------------------------------------------------------------------------------------|:------------------|:------------|
| vmName             | Name of the virtual machine                                                                                           |                   | chef-svr-01 |
| adminUsername      | SSH username for the server                                                                                           | azure             |             |
| adminPassword      | Password for the admin user                                                                                           |                   |             |
| dnsLabelPrefix     | Name that will be assigned to the DNS to make an FQDN for the machine. Typically this would be the same as the vmName |                   | chef-svr-01 |
| chefServerSKU      | Name of the Chef Server SKU to use.                                                                                   | chefbyol          |             |
| chefAdminUser      | Username of the account to create on the chef server                                                                  | admin             |             |
| chefAdminPassword  | Password to be associated with the admin user                                                                         |                   |             |
| chefAdminFirstname | Firstname of the admin account user                                                                                   | Admin             |             |
| chefAdminLastname  | Lastname of the admin account user                                                                                    | Account           |             |
| chefAdminEmail     | Email address for the admin account                                                                                   |                   |             |
| chefOrganization   | Name of the first organization to create on the chef server                                                           |                   | AzureOrg    |
| customScriptURL    | The Public URL from which the script to setup the server can be downloaded from.                                      | &lt;SEE BELOW&gt; |             |

Any of the parameters that have a default value do not appear in the `chefserver.parameters.json` file.  However to override the values add them to this file as required.

The organization name will be converted to lowercase when passed to the configuration script as this is a requirement of the chef server.  Ensure that the organization name does not contain spaces.

The `customScriptURL` is set to 'https://raw.githubusercontent.com/chef-partners/arm-chef-server/master/scripts/setup-chefserver.sh' by default which is the script in this repo `scripts\setup-chefserver.sh`.

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

| Name           | Description                                                                                                             |
|:---------------|:------------------------------------------------------------------------------------------------------------------------|
| fqdn           | The fully qualified domain name of the server.  This will be of the form <dnsLabelPrefix>.<location>.cloudapp.azure.com |
| sshCommand     | The ssh command required to login to the server with the correct user                                                   |
| chefServerUrl  | The concatenated URL for the server which includes the organization name                                                |
| starterKitPage | URL to the page on the server where the validation keys can be downloaded                                               |

![ARM Template Outputs](/images/outputs.png)

Use the `startKitPage` URL to regenerate the organization keys by clicking on 'Download Starter Kit' on the page.

For more information about using the Azure Marketplace chef server please refer to https://docs.chef.io/azure_portal.html.
