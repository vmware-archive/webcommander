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
		Run script remotely

	.DESCRIPTION
		This command runs a user defined script on Windows machine.
		This command could execute on multiple machines.
		
	.FUNCTIONALITY
		Windows
		
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
		Mandatory=$true,
		HelpMessage="Script to run"
	)]
	[string]
		$script,
	
	[parameter(
		HelpMessage="Type of script
			Bat: asynchronous, command returns immediately after triggering the script
			Powershell: synchronous, command returns on script completion
			Interactive: synchronous, guestUser must have already logged on
			InteractivePs1: synchronous, guestUser must have already logged on"
	)]
	[ValidateSet(
		"Bat",
		"Powershell",
		"Interactive",
		"InteractivePs1"
	)]
	[string]	
		$type="Bat"
)

foreach ($paramKey in $psboundparameters.keys) {
	$oldValue = $psboundparameters.item($paramKey)
	$newValue = [system.web.httputility]::urldecode("$oldValue")
	set-variable -name $paramKey -value $newValue
}

. .\objects.ps1

function runScript {
	param ($ip, $guestUser, $guestPassword, $script, $type)
	$remoteWin = newRemoteWin $ip $guestUser $guestPassword

	if ($type -eq "Powershell") {
		$result = $remoteWin.executePsTxtRemote($script, "run powershell script in VM")
	} elseif ($type -eq "interactive"){
		$result = $remoteWin.runInteractiveCmd($script)
	} elseif ($type -eq "interactivePs1"){
		$result = $remoteWin.runInteractivePs1($script)
	} else {
		$script | set-content "..\www\upload\$ip.txt"
		$remoteWin.sendFile("..\www\upload\$ip.txt", "c:\temp\script.bat")
		$script = "Invoke-WmiMethod -path win32_process -name create -argumentlist 'c:\temp\script.bat'"
		$result = $remoteWin.executePsTxtRemote($script, "trigger batch script in VM")
	}
	writeStdout $result
}

$ipList = getVmIpList $vmName $serverAddress $serverUser $serverPassword
$ipList | % {
	runScript $_ $guestUser $guestPassword $script $type
}