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
        Create users and groups in AD.

	.DESCRIPTION
        This command creates users and groups in AD.
		Users will be averagely added into each group.
		For instance, when there are 100 users and 10 groups:
		user-1 to user-10 will be in group-1, user-11 to 
		user-20 will be in group-2, etc.
		
	.FUNCTIONALITY
		AD
	
	.NOTES
		AUTHOR: Jerry Liu
		EMAIL: liuj@vmware.com
#>

Param (
	[parameter(
		HelpMessage="IP or FQDN of the ESX or VC server where the domain controller VM is located"
	)]
	[string]$serverAddress, 
	
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
		HelpMessage="Name of the VM or IP / FQDN of remote Windows machine"
	)]
	[string]
		$vmName,
	
	[parameter(
		HelpMessage="User of guest OS or remote Windows machine (default is administrator)"
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
		HelpMessage="Prefix of user name"
	)]
	[string]
		$userPrefix, 
		
	[parameter(
		HelpMessage="Number of users to create, default is 1"
	)]
	[string]
		$totalUser=1,
	
	[parameter(
		HelpMessage="User password (default is VMware standard)"
	)]
	[string]	
		$userPassword=$env:defaultPassword,
		
	[parameter(
		Mandatory=$true,
		HelpMessage="Prefix of group name"
	)]
	[string]
		$groupPrefix,
		
	[parameter(
		HelpMessage="Number of groups to create, default is 1"
	)]
	[string]
		$totalGroup=1
)

foreach ($paramKey in $psboundparameters.keys) {
	$oldValue = $psboundparameters.item($paramKey)
	$newValue = [system.web.httputility]::urldecode("$oldValue")
	set-variable -name $paramKey -value $newValue
}

. .\objects.ps1

if (verifyIp($vmName)) {
	$ip = $vmName
} else {
	$server = newServer $serverAddress $serverUser $serverPassword
	$vm = newVmWin $server $vmName $guestUser $guestPassword
	$vm.waitfortools()
	$ip = $vm.getIPv4()
	$vm.enablePsRemote()
}

$createUserAndGroup = {
	Param (
		$userPrefix,
		$totalUser,
		$userPassword,
		$groupPrefix,
		$totalGroup
	)

	$userPerGroup = [math]::floor($totalUser / $totalGroup)

	$p = ConvertTo-SecureString $userPassword -asPlainText -Force

	import-module activedirectory -ea silentlycontinue

	get-aduser -filter "name -like '$userPrefix*'" | remove-aduser -confirm:$false
	get-adgroup -filter "name -like '$groupPrefix*'" | remove-adgroup -confirm:$false

	(1..$totalUser) | % {
		new-aduser -name "$userPrefix$_" -accountPassword $p -cannotChangePassword:$true -enabled:$true
	} 
	(1..$totalGroup) | % {
		new-adGroup -name "$groupPrefix$_" -groupscope global
	} 
	(1..$totalGroup) | %{
		$user = @()
		for ($i=1; $i -le $userPerGroup; $i++){
			$number = ($_ - 1) * $userPerGroup + $i
			$user += "$userPrefix$number"
		}  
		add-adgroupmember "$groupPrefix$_" $user
	}
}

$remoteWin = newRemoteWin $ip $guestUser $guestPassword
try {
	invoke-command -ScriptBlock $createUserAndGroup -session $remoteWin.session -EA stop `
		-argumentlist $userPrefix, $totalUser, $userPassword, $groupPrefix, $totalGroup
} catch {
	writeCustomizedMsg "Fail - create AD user and group"
	writeStderr
	[Environment]::exit("0")
}
writeCustomizedMsg "Success - create AD user and group"