# Change Log

## 1.0.0.4 (2016-05-17)

**Implemented Enhancements**

 - Virtual Network and Storage Accounts can be specified as `new` or `exists`.  If `new` (default) the template will create the artefact, if `exists` then it can be passed in from another template consuming it.
 - Added parameters to support the `new` or `exists` modes
 - New parameter added called `baseUrl` which is the base URL from where all the templates can be retrieved.  This is defaulted to the location in GitHub but can be overridden so other locations can be used, such as Dropbox for testing

## 1.0.0.3 (2016-05-09)

**Implemented Enhancements**

 - Removed the need for a script to configure the chef server after creation.  This is now done through `cloud-init`.
 - Updated the README file
 - Added buttons to create machines in Azure direct from the repo

## 1.0.0.2 (2016-05-06)

**Implemented Enhancements**

 - Script modified to reflect the setup and configuration changes in the new Chef AMP image (3.1.0)
 - Updated template so that it is possible to use as part of a larger ARM template using shared URLs
 - URL to the signup page has been added as an output of the template
 - Added CHANGELOG file
