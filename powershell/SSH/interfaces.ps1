<#
Copyright (c) 2012-2015 VMware, Inc.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
#>

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
##################### Start general parameters #####################
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
##################### Start uploadFile parameters #####################	
	[parameter(
    parameterSetName="uploadFile",
		HelpMessage="Files to copy from local server or online. Each file per line."
	)]
	[string]
		$fileUrl,
	
	[parameter(
    parameterSetName="uploadFile",
		HelpMessage="File to upload from client machine"
	)]
	[string]
		$file,
	
	[parameter(
    parameterSetName="uploadFile",
		Mandatory=$true,
		HelpMessage="Destination path, such as /home/temp/"
	)]
	[string]
		$destination,
    
  [parameter(
    parameterSetName="uploadFile",
		HelpMessage="Protocol"
	)]
  [ValidateSet(
		"scp",
		"sftp"
	)]
	[string]
		$protocol="scp",
    
  [parameter(
    parameterSetName="uploadFile",
    helpMessage="Upload file to remote machine"
	)]
  [switch]
		$uploadFile,
 ##################### Start runScript parameters #####################  
  [parameter(
    parameterSetName="runScript",
		Mandatory=$true,
		HelpMessage="Script text"
	)]
	[string]
		$scriptText,
		
	[parameter(
    parameterSetName="runScript",
		HelpMessage="Method to check if specific string could (or could not) be found in output. Default is 'like'."
	)]
	[ValidateSet(
		"like",
		"notlike",
		"match",
		"notmatch"
	)]
	[string]
		$outputCheck="like",
		
  [parameter(
    parameterSetName="runScript",
		HelpMessage="String pattern to find"
	)]
	[string]
		$pattern,
  
  [parameter(
    parameterSetName="runScript"
	)]
  [switch]
		$runScript
)

foreach ($paramKey in $psboundparameters.keys) {
  $oldValue = $psboundparameters.item($paramKey)
  if ($oldValue.gettype().name -eq "String") {
    $newValue = [system.web.httputility]::urldecode("$oldValue")
    set-variable -name $paramKey -value $newValue
  }
}

. .\utils.ps1
. .\ssh\object.ps1

$serverList = @($serverAddress.split(",") | %{$_.trim()})
switch ($pscmdlet.parameterSetName) {
  "uploadFile" {
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
  "runScript" {
    $serverList | % {
      $sshServer = newSshServer $_ $serverUser $serverPassword
      $sshServer.runCommand($scriptText, $outputCheck, $pattern)
    }
  }
}
writeResult