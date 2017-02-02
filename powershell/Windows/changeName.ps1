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
		Change machine name 

	.DESCRIPTION
		This command changes name of Windows machine.
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
		HelpMessage="Name of target VM or IP / FQDN of target machine. 
			Support multiple values seperated by comma. VM name and IP could be mixed."
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
		HelpMessage="New machine name. Support multiple values seperated by comma."
	)]
	[string]
		$newGuestName
)

foreach ($paramKey in $psboundparameters.keys) {
	$oldValue = $psboundparameters.item($paramKey)
	$newValue = [System.Net.WebUtility]::urldecode("$oldValue")
	set-variable -name $paramKey -value $newValue
}

. .\objects.ps1

function changeMachineName{
	param ($ip, $guestUser, $guestPassword, $newGuestName)
	$remoteWin = newRemoteWin $ip $guestUser $guestPassword
	$cmd = {
		param($newName, $password, $userName)
		(Get-WmiObject -class win32_computersystem).Rename($newName, $password, $userName)
	}
	$result = invoke-command -scriptblock $cmd -session $remoteWin.session -argumentlist $newGuestName, $guestPassword, $guestUser
	if ($result.returnValue -eq 0) {
		writeCustomizedMsg "Success - rename hostname to $newGuestName"
		$remoteWin.restart()
	} else {
		writeCustomizedMsg "Fail - rename hostname to $newGuestName"
		writeCustomizedMsg ("Info - return value is " + $result.returnvalue)
	}
}	

$ipList = getVmIpList $vmName $serverAddress $serverUser $serverPassword
$newNameList = parseInput $newGuestName
if ($ipList.count -ne $newNameList.count) {
	writeCustomizedMsg "Fail - machine number and name number don't match"
	[Environment]::exit("0")
}
for ($i=0;$i -lt $ipList.count; $i++) {
	changeMachineName $ipList[$i] $guestUser $guestPassword $newNameList[$i]
}