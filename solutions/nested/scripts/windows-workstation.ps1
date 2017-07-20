# 
# Script to configure a Windows Workstation for the Automate Cluster
#

[CmdletBinding()]
param (
  [string]
  # String array of operations that can be performed
  $operation,

  [string]
  # Version of the ChefDK to download
  $chefdk_version,

  [string]
  # Chef repo
  $chef_repo_url,

  [string]
  # Chef organisation
  $chef_org,

  [string]
  # Chef Server url
  $chef_server_url,

  [string]
  # Chef user
  $chef_user,

  [string]
  # The windows user name
  # It is copied into here so that all new users that logon will have this structure
  $windows_user = "azure",

  [string]
  $windows_password,

  [string]
  # IP Address of the orchestration server
  $orchestrationserver = "10.0.0.4:4001",

  [string]
  # Subscription ID
  $subscriptionId = "",

  [string]
  # Password associated with the subscription
  $subscriptionPassword = "",

  [string]
  # Password associated with the subscription
  $subscriptionUsername = "",

  [string]
  # Location in Azure
  $azurelocation = "",

  [string]
  # Client id
  $clientId,

  [string]
  # client secret
  $clientSecret,

  [string]
  # tenant id
  $tenantId,

  [string]
  $automateServerFQDN,

  [string]
  $automateServerUrl

)

Add-Type -AssemblyName System.IO.Compression.FileSystem

function Unpack {

  [CmdletBinding()]
  param (
    [string]
    # Path to unpack to
    $path,

    [string]
    # Path to the archive package
    $archive
  )

  # Check the version of powershell
  if ($PSVersionTable.PSVersion.Major -ge 5) {

    Expand-Archive -Path $archive -DestinationPath $path
  } else {
  
    # open he zip file
    $zip = [System.IO.Compression.ZipFile]::OpenRead($archive)

    foreach ($item in $zip.Entries) {

      # Determine the path that should be extracted to
      $itempath = $item.Fullname

      $itempath = Join-Path -Path $path -ChildPath $itempath

      # Ensure that the directory exists, use the length of the item to determine if it is a directory
      if ($item.length -eq 0 -and !(Test-Path -Path $itempath)) {
          Write-Verbose -Message ("Creating Dir: {0}" -f $itempath)
          New-Item -type directory -Path $itempath | Out-Null
      }

      # Only extract files with content in them
      # if ($item.length > 0) {
          try {
              [System.IO.Compression.ZipFileExtensions]::ExtractToFile($item, $itempath, $true)
          } catch {
              $_
          }
      #}

    }
  }

  # Ensure that the zip item is disposed of, this is to remove the lock on the file
  $zip.Dispose()

}

function Execute-Command {

  param (
    [string]
    # The executable command to call
    $command,

    [string]
    # Arguments to pass to the command
    $arguments,

    [string]
    # Username under which the command should be run
    $username = [String]::Empty,

    [string]
    # Password for the specified user
    $password = [String]::Empty,

    [string]
    # Working directory for the Process
    $workingdir = [String]::Empty
  
  )

  $psi = New-object System.Diagnostics.ProcessStartInfo 
  $psi.FileName = $command
  $psi.Arguments = $arguments

  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true

  $psi.CreateNoWindow = $true 
  $psi.UseShellExecute = $false 

  # add in username and password if they have been specified
  if (![String]::IsNullOrEmpty($username) -and ![String]::IsNullOrEmpty($password)) {
    $psq.Domain = $env:COMPUTERNAME
    $psi.Username = $username
    $psi.Password = ConvertTo-SecureString $password -AsPlainText -Force
  }

  # if a working directory has been specified add it here
  if (![String]::IsNullOrEmpty($workingdir)) {
    $psi.WorkingDirectory = $workingdir
  }
   
  $process = New-Object System.Diagnostics.Process 
  $process.StartInfo = $psi 

  [void]$process.Start()
  $stdout = $process.StandardOutput.ReadToEnd() 
  $stderr = $process.StandardError.ReadToEnd()
  $process.WaitForExit() 
  
  # merge the stdout and the stderr and return
  return $stdout + $stderr
}

# Set the path to the repo based on the windows user
$homedir = "C:\Users\{0}" -f $windows_user
$path = "C:\Users\{0}" -f $windows_user

# Split the modes up so that they can be iterated over
# This is not set as an array in the parameters because when they are passed from the cmd they are seen as a string
$modes = $operation -split ","

# Iterate around the mode that has been set
foreach ($mode in $modes) {

  switch ($mode) {
    "chefdk" {

      # Download and install the ChefDK on the machine
      # This is required so that the chef-client can be run, this machine will
      # not be managed by the Automate Chef server
      $url = "https://packages.chef.io/stable/windows/2008r2/chefdk-{0}-1-x86.msi" -f $chefdk_version

      # Define the download file
      $target = "{0}\{1}" -f $((Get-Location).Path), $(Split-Path -Leaf -Path $url)

      # Use the .NET Webclient to download the file
      $wc = New-Object System.Net.WebClient
      $wc.DownloadFile($url, $target)

      # Install the package now it has been downloaded
      Start-Process C:\Windows\System32\msiexec.exe -ArgumentList "/i $target /quiet" -Wait

    }

    "chefrepo" {

      # Download and unpack the repo from the storage account
      $target = "C:\Users\Default\{0}" -f $(Split-Path -Leaf -Path $chef_repo_url)

      # Use the .NET Webclient to download the file
      $wc = New-Object System.Net.WebClient
      $wc.DownloadFile($chef_repo_url, $target)

      Unpack -path "C:\Users\Default" -archive $target
    }

    "chefclient" {

      $current_path = (Get-Location).Path

      # Change to the root of the repo so that the chef-client can find everything
      Set-Location -Path $path

      # Build up the JSON string to pass to the client which will have the information about the chef server
      $data = @{
        workstation = @{
          "chef_server" = @{
            organisation = $chef_org
            url = $chef_server_url
            user = $chef_user
          }
          user = @{
            default = @{
              home = $homedir
            }
          }
          automate = @{
            fqdn = $automateServerFQDN
            url = $automateServerUrl
          }
        }
        azure = @{
          location = $azurelocation
          subscription = @{
            id = $subscriptionId
            password = $subscriptionPassword
            username = $subscriptionUsername
          }
          spn = @{
            client_id = $clientId
            client_secret = $clientSecret
            tenant_id = $tenantId
          } 
        }
      }

      Write-Output "Creating first run JSON attributes file"

      # Write out the json file
      Set-Content -Path "c:\Users\Default\first-run.json" -Value ($data | ConvertTo-Json -Depth 100)

      # get the cookbook dependencies
      Write-Output "Getting cookbook dependencies"

      $cmd = "C:\Windows\System32\cmd.exe"
      $arglist = "/c c:\opscode\chefdk\bin\berks vendor c:\Users\Default\cookbooks"

      Write-Output ("Running command: {0} {1}" -f $cmd, $arglist)

      $output = Execute-Command -command $cmd -arguments $arglist -WorkingDir "c:\Users\Default\cookbooks\workstation"
      write-output $output

      Write-Output "Initial Chef-Client Run"

      # This mode runs the specified recipe on the host using chef-client local mode
      $cmd = "C:\Windows\System32\cmd.exe"
      $arglist = "C:\opscode\chefdk\bin\chef-client --local-mode -o recipe[workstation::automate] -j first-run.json -L first-run.log"

      $body = @()
      $body += "cd c:\Users\Default"
      $body += $arglist

      # Save the arglist as a batch file to be scheduled
      $batch_file_path = "c:\windows\temp\chef-client-initial.bat"
      Set-Content -Path $batch_file_path -Value ($body -join "`r`n")
      
      # In order to run the initial chef-client PSExec needs to be used.  This is so that it is run as
      # a normal user outside of the local system account.  This is required for the chocolately installation
      # of the packages.  This executable is expected to be in the chefrepo dir.

      $cmd = "c:\Users\Default\bin\PSExec.exe"
      $arglist = "-accepteula -u $windows_user -p `"$windows_password`" -h c:\windows\system32\cmd.exe /c c:\windows\temp\chef-client-initial.bat"

      Write-Output ("Running command: {0} {1}" -f $cmd, $arglist)
      $output = Execute-Command -command $cmd -arguments $arglist

      Write-Output $output

      Set-Location -Path $current_path
    }

    "infranode" {

      # Obtain the validation key from the orchestration server and then run the chef client
      $uri = "http://{0}/v2/keys/{1}/validator" -f $orchestrationserver, $chef_org.toLower()
      $data = Invoke-RestMethod -Uri $uri

      # Decode the Base64 encoded string and save the file in the correct place
      $bytes = [System.Convert]::FromBase64String($data.node.value)
      $path = "C:\chef\validation.pem"
      Set-Content -Path $path -Value $([System.Text.Encoding]::UTF8.GetString($bytes))

      # Get the data_token and the automate server FQDN from the orchestration server
      $uri = "http://{0}/v2/keys/automate/token" -f $orchestrationserver
      $data_token = (Invoke-RestMethod -Uri $uri).node.value

      $uri = "http://{0}/v2/keys/automate/fqdn" -f $orchestrationserver
      $automate_fqdn = (Invoke-RestMethod -Uri $uri).node.value

      # Build up the string to insert into the client.rb configuration file
      $configuration = @"

# Settings to get chef-client to report to the automate cluster properly
data_collector.server_url "https://{0}/data-collector/v0/"
data_collector.token "{1}"
"@ -f $automate_fqdn, $data_token

      # Append this to the configuration file
      Add-Content -Path "C:\chef\client.rb" -Value $configuration

      # Run the chef-client with the appropriate parameters
      Start-Process "c:\opscode\chef\bin\chef-client" -argumentlist "-j c:\chef\first-boot.json" -Wait

    }

    default {
      Write-Output ("Unrecognised mode: {0}" -f $mode)
    }
  }
}