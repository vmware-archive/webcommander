<#
	.SYNOPSIS
		SSH 

	.DESCRIPTION
		Run commands on SSH servers.
		Copy files to SFTP servers.
		
	.NOTES
		AUTHOR: Jian Liu
		EMAIL: whirls9@hotmail.com
#>

Param (
	[parameter(
		Mandatory=$true,
		HelpMessage="IP or FQDN of SSH or SFTP server. Support multiple values seperated by comma."
	)]
	[string]
		$serverAddress, 
	
	[parameter(
		HelpMessage="User name to connect to the server (default is root)"
	)]
	[string]
		$serverUser="root", 
	
	[parameter(
		HelpMessage="Password of the user"
	)]
	[string]
		$serverPassword=$env:defaultPassword,  
	
	[parameter(
    parameterSetName="copyFile",
		HelpMessage="Files to copy from local server or online. Each file per line."
	)]
	[string]
		$fileUrl,
	
	[parameter(
    parameterSetName="copyFile",
		HelpMessage="File to upload from client machine"
	)]
	[string]
		$file,
	
	[parameter(
    parameterSetName="copyFile",
		Mandatory=$true,
		HelpMessage="Destination path, such as /home/temp/"
	)]
	[string]
		$destination,
    
  [parameter(
    parameterSetName="copyFile",
		HelpMessage="Protocol"
	)]
  [ValidateSet(,
		"scp",
		"sftp"
	)]
	[string]
		$protocol="scp",
    
  [parameter(
    parameterSetName="runCommand",
		Mandatory=$true,
		HelpMessage="Command to run"
	)]
	[string]
		$command,
		
	[parameter(
    parameterSetName="runCommand",
		HelpMessage="Method to check if specific string could (or could not) be found in output. Default is 'like'."
	)]
	[ValidateSet(,
		"like",
		"notlike",
		"match",
		"notmatch"
	)]
	[string]
		$outputCheck="like",
		
  [parameter(
    parameterSetName="runCommand",
		HelpMessage="String pattern to find"
	)]
	[string]
		$pattern
)

foreach ($paramKey in $psboundparameters.keys) {
	$oldValue = $psboundparameters.item($paramKey)
	$newValue = [system.web.httputility]::urldecode("$oldValue")
	set-variable -name $paramKey -value $newValue
}

. .\utils.ps1
. .\ssh\object.ps1

$serverList = @($serverAddress.split(",") | %{$_.trim()})
switch ($pscmdlet.parameterSetName) {
  "copyFile" {
    $files = getFileList $fileUrl
    if ($file) {$files += $file}
    if (!$files) {
      addToResult "Fail - find file to copy"
      endExec
    }
    $serverList | % {
      $sshServer = newSshServer $_ $serverUser $serverPassword
      if ($protocol -eq "sftp"){
        $files | % { $sshServer.copyFileSftp($_, $destination) }
      } else {
        $files | % { $sshServer.copyFileScp($_, $destination) }
      }
    }
  }
  "runCommand" {
    $serverList | % {
      $sshServer = newSshServer $_ $serverUser $serverPassword
      $sshServer.runCommand($command, $outputCheck, $pattern)
    }
  }
}
writeResult