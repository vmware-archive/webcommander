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
		Entitle application pools to users

	.DESCRIPTION
		This command entitles application pools to users or groups.
		This command could execute on multiple brokers to entitle multiple
		pools to multiple users or groups.
		
	.FUNCTIONALITY
		Broker_RDS
		
	.NOTES
		AUTHOR: Jerry Liu
		EMAIL: liuj@vmware.com
#>

Param (
	[parameter(
		HelpMessage="IP or FQDN of the ESX or VC server where the broker VM is located"
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
		HelpMessage="Name of broker VM or IP / FQDN of broker machine. Support multiple values seperated by comma. VM name and IP could be mixed."
	)]
	[string]
		$vmName, 
	
	[parameter(
		HelpMessage="User of broker (default is administrator)"
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
		HelpMessage="Application pool ID. Support multiple values seperated by comma. "
	)]
	[string]	
		$applicationId,
	
	[parameter(
		Mandatory=$true,
		HelpMessage="User or group name in 'domain\user' format. Support multiple values seperated by comma. "
	)]
	[string]	
		$userName
)

foreach ($paramKey in $psboundparameters.keys) {
	$oldValue = $psboundparameters.item($paramKey)
	$newValue = [system.web.httputility]::urldecode("$oldValue")
	set-variable -name $paramKey -value $newValue
}

. .\objects.ps1

function entitleApp {
	param ($ip, $guestUser, $guestPassword, $appList, $userList)
	$remoteWinBroker = newRemoteWinBroker $ip $guestUser $guestPassword
	$remoteWinBroker.initialize()
	foreach ($app in $appList) {
		foreach ($userName in $userList) {
			$domain = $userName.split("\")[0]
			$user = $userName.split("\")[1]
			$remoteWinBroker.entitleRdsAppPool($user,$domain,$app)
		}
	}
}

$appList = $applicationId.split(",") | %{$_.trim()}
$userList = $userName.split(",") | %{$_.trim()}
$ipList = getVmIpList $vmName $serverAddress $serverUser $serverPassword
$ipList | % {
	entitleApp $_ $guestUser $guestPassword $appList $userList
}