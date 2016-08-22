# Download the latest Azure PowerShell SDK here - http://aka.ms/webpi-azps

[CmdletBinding()] 
param 
(
	[Parameter(Mandatory)]
	[ValidateNotNullOrEmpty()]
	[System.String]$AzureADServicePrincipalFriendlyName
)

Write-Verbose -Message "Starting script $($MyInvocation.MyCommand)"

$RepositoryName = 'PSGallery'
Try
{
    Get-PSRepository -Name $RepositoryName -ErrorAction Stop
}
catch
{
    Write-Verbose -Message "Unable to find PowerShell repository '$RepositoryName'"
    break
}

$ModuleName = 'AzureRM.profile'
$ModuleLatest = Find-Module -Name $ModuleName -Repository $RepositoryName
$ModuleInstalled = Get-InstalledModule -Name $ModuleName -ErrorAction SilentlyContinue
if (($ModuleInstalled -eq $null) -or ($ModuleLatest.Version -gt $ModuleInstalled.Version))
{
    Write-Verbose -Message "Installing PowerShell module $ModuleName v$($ModuleLatest.Version)"
    Install-Module -Name $ModuleName -RequiredVersion $ModuleLatest.Version -Repository $RepositoryName -Scope CurrentUser -Force
}

$ModuleName = 'AzureRM.Resources'
$ModuleLatest = Find-Module -Name $ModuleName -Repository $RepositoryName
$ModuleInstalled = Get-InstalledModule -Name $ModuleName -ErrorAction SilentlyContinue
if (($ModuleInstalled -eq $null) -or ($ModuleLatest.Version -gt $ModuleInstalled.Version))
{
    Write-Verbose -Message "Installing PowerShell module $ModuleName v$($ModuleLatest.Version)"
    Install-Module -Name $ModuleName -RequiredVersion $ModuleLatest.Version -Repository $RepositoryName -Scope CurrentUser -Force
}

try
{
    Write-Verbose -Message 'Check to see if we are authenticated.'
    $AzureContext = Get-AzureRmContext -ErrorAction Stop
}
catch
{
    try
    {
		Write-Verbose -Message 'Authenticating Add-AzureRmAccount.'
		$AzureAccount = Add-AzureRmAccount -ErrorAction Stop
		$AzureContext = $AzureAccount.Context
	}
	catch
	{
		Write-Verbose -Message 'Failed to authenticate.'
		break
    }
}
Write-Verbose -Message "AzureContext: $($AzureContext | Format-List | Out-String)"

Write-Verbose -Message 'Generate a unique name for an Azure AD Application'
$AzureADApplicationName = "$($AzureContext.Subscription.SubscriptionId)-$(Get-Date -Format("yyyy-MM-dd-HH-mm-ss"))-application"

Write-Verbose -Message 'Generate a random number to be used as the Azure AD application key' 
$ApplicationKey = New-Object Byte[] 32
$RandomNumber = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$RandomNumber.GetBytes($ApplicationKey)
$ApplicationKeyBase64 = [System.Convert]::ToBase64String($ApplicationKey)
$ApplicationKeyEndDate = [System.DateTime]::Now.AddYears(2)

Write-Verbose -Message 'Create the Azure AD application.' 
try
{
	$AzureADApplication = New-AzureRmADApplication -DisplayName "$AzureADServicePrincipalFriendlyName" -HomePage "https://$($AzureADApplicationName)" -IdentifierUris "https://$($AzureADApplicationName)" -Password $ApplicationKeyBase64 -EndDate $ApplicationKeyEndDate -ErrorAction Stop
}
catch
{
	Write-Verbose -Message 'Failed to create the Azure AD application.'
	break
}

Write-Verbose -Message 'Create the Azure AD service principal'
try
{
	$AzureADServicePrincipal = New-AzureRmADServicePrincipal -ApplicationId $AzureADApplication.ApplicationId.Guid -ErrorAction Stop
}
catch
{
	Write-Output -Message 'Failed to create the AD service principal.'
	break
}

Write-Verbose -Message 'The Azure AD service principal might take some time to be created, so loop every 5 seconds until we are able to Assign RBAC permissions.'
$Retry = $true
do
{
	try
	{
		Write-Verbose -Message 'Assign the Contributor role to Azure AD service principal'
		New-AzureRmRoleAssignment -RoleDefinitionName Contributor -ServicePrincipalName $AzureADServicePrincipal.ApplicationId -ErrorAction Stop
		$Retry = $false
	}
	catch
	{
		Write-Verbose -Message 'Sleep for 5 seconds.'
		Start-Sleep -Seconds 5
	}
}
while ($Retry -eq $true)

Write-Verbose -Message 'Generate Chef Test Kitchen "credentials" file, located in the ".azure" folder of the user''s home directory.'

# Determine the path to the credentials file
$credentials_path = "~/.azure/credentials"

if (Test-Path -Path $credentials_path) {

	# Move the existing file to a backup
	$backup_path = "~/.azure/credentials.bak-{0}" -f ([int][double]::Parse((get-date -uformat %s)))

	Copy-Item $credentials_path $backup_path

	Write-Verbose -Message ("Existing credentials file saved to: {0}" -f $backup_path)
}

$CredentialsFile = New-Item "~\.azure\credentials" -ItemType file -Force
$CredentialsFileWriteFilestream = $CredentialsFile.CreateText()
$CredentialsFileWriteFilestream.WriteLine("[$($AzureContext.Subscription.SubscriptionId)]")
$CredentialsFileWriteFilestream.WriteLine("client_id = ""$($AzureADApplication.ApplicationId.Guid)""")
$CredentialsFileWriteFilestream.WriteLine("client_secret = ""$ApplicationKeyBase64""")
$CredentialsFileWriteFilestream.WriteLine("tenant_id = ""$($AzureContext.Tenant.TenantId)""")
$CredentialsFileWriteFilestream.Close()

Write-Verbose -Message "Finished script $($MyInvocation.MyCommand)"