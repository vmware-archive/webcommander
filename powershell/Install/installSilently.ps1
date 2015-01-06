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
		Install application silently 

	.DESCRIPTION
		This command downloads and installs an application silently.
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
		HelpMessage="Snapshot name. If defined, VM will be restored to the snapshot first."
	)]
	[string]
		$ssName, 
	
	[parameter(
		Mandatory=$true,
		HelpMessage="URL to the installer file"
	)]
	[string]
		$installerUrl, 
	
	[parameter(
		HelpMessage="Silent install parameters, such as ' /s /v /qn'"
	)]
	[string]
		$silentInstallParam,
	
	[parameter(
		HelpMessage="Download the installer without installing it"
	)]
	[ValidateSet(
		"false",
		"true"
	)]
	[string]
		$downloadOnly="false"
)

foreach ($paramKey in $psboundparameters.keys) {
	$oldValue = $psboundparameters.item($paramKey)
	$newValue = [system.web.httputility]::urldecode("$oldValue")
	set-variable -name $paramKey -value $newValue
}

. .\objects.ps1

$installer = ($installerUrl.split("/"))[-1]
$cmd1 = "
	new-item c:\temp -type directory -force | out-null
	`$wc = new-object system.net.webclient;
	`$wc.downloadfile('$installerUrl', 'c:\temp\$installer');
	get-item 'c:\temp\$installer' -ea Stop | out-null
"
$cmd2 = "	
	`$installprocess = [System.Diagnostics.Process]::Start('c:\temp\$installer', '$silentInstallParam')
	`$installprocess.WaitForExit()
	If ((0,1641,3010) -notcontains `$installprocess.ExitCode) {    
		throw ('Fail to install $installer. Exit code:' + `$installprocess.ExitCode)
	}
"

function silentInstall {
	param ($ip, $guestUser, $guestPassword, $downloadOnly)
	$remoteWin = newRemoteWin $ip $guestUser $guestPassword
	$remoteWin.executePsTxtRemote($cmd1, "download file $installer", "1200")
	if ($downloadOnly -eq "true") {
		return
	}
	$remoteWin.executePsTxtRemote($cmd2, "install $installer", 2400)
}

if ($ssName) {
	restoreSnapshot $ssName $vmName $serverAddress $serverUser $serverPassword
}

$ipList = getVmIpList $vmName $serverAddress $serverUser $serverPassword
$ipList | % {
	silentInstall $_ $guestUser $guestPassword $downloadOnly
}