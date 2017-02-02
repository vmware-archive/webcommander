<#
Copyright (c) 2012-2014 VMware, Inc.

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
		Install WebCommander 

	.DESCRIPTION
		This command installs and configures WebCommander.
		This command could execute on multiple machines.
		
	.FUNCTIONALITY
		Install
		
	.NOTES
		AUTHOR: Jerry Liu
		EMAIL: liuj@vmware.com
#>

Param (
	[parameter(
		HelpMessage="IP or FQDN of the ESX or VC server where target VM is located"
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
		Mandatory=$true,
		HelpMessage="Name of target VM or IP / FQDN of target machine. Support multiple values seperated by comma. VM name and IP could be mixed."
	)]
	[string]
		$vmName, 
	
	[parameter(
		HelpMessage="User of target machine (default is administrator)"
	)]
	[string]	
		$guestUser="administrator", 
		
	[parameter(
		HelpMessage="Password of guestUser"
	)]
	[string]	
		$guestPassword=$env:defaultPassword,
		
	[parameter(
		HelpMessage="URL to WebCommander package, default is https://github.com/vmware/webcommander/archive/master.zip"
	)]
	[string]
		$packageUrl="https://github.com/vmware/webcommander/archive/master.zip",
		
	[parameter(
		HelpMessage="Authentication type of WebCommander web applcation, default is 'Windows'"
	)]
	[ValidateSet(
		"Windows",
		"Anonymous"
	)]
	[string]
		$authentication="windows",
	
	[parameter(
		HelpMessage="Default password that will be used by WebCommander commands"
	)]
	[string]
		$defaultPassword=$env:defaultPassword
)

foreach ($paramKey in $psboundparameters.keys) {
	$oldValue = $psboundparameters.item($paramKey)
	$newValue = [System.Net.WebUtility]::urldecode("$oldValue")
	set-variable -name $paramKey -value $newValue
}

. .\objects.ps1

function installWebCommander {
	param ($ip, $guestUser, $guestPassword, $packageUrl, $authentication, $defaultPassword)
	$remoteWin = newRemoteWin $ip $guestUser $guestPassword
	$remoteWin.sendFile(".\install\setup.ps1","c:\temp\setup.ps1")
	$cmd = "c:\temp\setup.ps1 '$packageUrl' '$authentication' '$guestPassword' '$defaultPassword'"
	$result = $remoteWin.executePsTxtRemote($cmd, "trigger setup script in remote machine")
	writeStdout $result
	if (($result -match "WebCommander website updated successfully") `
		-or ($result -match "WSMAN settings changed successfully")) {
		writeCustomizedMsg "Success - install WebCommander"
	} else {
		writeCustomizedMsg "Fail - install WebCommander"
	}
}

$ipList = getVmIpList $vmName $serverAddress $serverUser $serverPassword
$ipList | % {
	installWebCommander $_ $guestUser $guestPassword $packageUrl $authentication $defaultPassword
}