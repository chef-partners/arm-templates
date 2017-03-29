# Azure Resource Manager (ARM) Example Templates

## NOTE:  This repo has been consolidated so that only the latest versions of templates are accessible in the `master` branch.  For reference only please refer to the [`archive`](https://github.com/chef-partners/arm-templates/tree/archive) branch which contains all the old templates.

This repository contains ARM templates that can be used to create various Chef solutions:

 - Chef Automate Cluster
 - Chef Workstation
 - Chef Nodes

The templates can be used on their own or there are some that combine many templates into one.  Of course it is possible to create your own templates that consume other templates within the solutions folder.

Please refer to the [README](solutions/README.md) file in the solutions directory for more information about the individual templates.

## Deploying Templates

In order to help with the deployment of templates into Azure and manage the Resource Groups a number of Thor tasks have been created.  To use them please ensure that you run `bundle` so that Thor is installed.

**NOTE:  The Azure XPlat CLI tools must be installed for these tasks to be used.**

To see what tasks are available run the following:

```bash
thor -T
```

Thr output will be similar to the following:

```bash
deploy
------
thor deploy:create [URI] [PARAMETERS_PATH] [GROUP]  # Create a deployment in Azure
thor deploy:status [RESOURCE_GROUP]                 # Check the status of a deployment in Azure
```

### deploy:create

The following shows how the `deploy:create` task can be used to deploy the Chef Automate cluster template.

```bash
thor deploy:create https://raw.githubusercontent.com/chef-partners/arm-templates/master/solutions/automatecluster-infranodes.json local/automatecluster.parameters.json chef-automate
```

If this is the first time the command has been run a new resource group will be created called `chef-automate-1`.  This is tracked by a file which will be created in `.thor/deploy.json`.

Subsequent runs of the task will destroy the old resource group and then create a new one with the number incremented.  This allows for the rapid testing of templates.

When using the task there are two rules that must be followed:

 1. The path to the template MUST be a full URI to the template
 2. The URI must represent a Public URL that Azure is able to access.  The entire solution folder must be available from the parent folder as specified in the URI.
     - Use GitHub branches for testing for example
     - Upload files to your own webspace

The following table shows the additional options that can be passed to the task.

| Option | Description | Default |
|--------|-------------|---------|
| --count | The index to use for the resource group | 1 |
| --no-delete | Do not delete the previous resource group | |
| --location | Where the deployment should occur in Azure | westeurope |
| --dryrun | Perform a dryrun to determine what will happen | |
| --no-wait | Do not block the command line for the deployment.  Deployment status can be retrieved from the Azure Portal or using the `deploy:status` task | |

In the above example the parameters file comes from a `local` directory in the repo.  If this folder is created it will be ignored by `git`.  It is recommended that any parameters files are created in here especially if they contain passwords and / or private keys.

### deploy:status

This task checks the status of a deployment to the resource group.  Only the latest deployment status is displayed.

```bash
thor deploy:status chef-automate
```

**NOTE:  Do not append the index to the resource group as this will be done by the task from the tracking file**


