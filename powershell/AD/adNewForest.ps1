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
        Create a forest

	.DESCRIPTION
        This command creates a new forest, namely to creat the first domain in the forest.
		
	.FUNCTIONALITY
		AD
#>

## Author: Jerry Liu, liuj@vmware.com

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
		HelpMessage="Name of the domain to create"
	)]
	[string]
		$domainName, 
		
	[parameter(
		Mandatory=$true,
		HelpMessage="Netbios name (short name) of the domain"
	)]
	[string]
		$domainName,
	
	[parameter(
		Mandatory=$true,
		HelpMessage="Forest mode"
	)]
	[ValidateSet(
		"Win2003",
		"Win2008",
		"Win2008R2",
		"Win2012"
	)]
	[string]
		$forestMode,
		
	[parameter(
		HelpMessage="Safe mode administrator password (default is VMware standard)"
	)]
	[string]
		$safeModePassword=$env:defaultPassword
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

$createNewForest = {
	Param ($domainName, $netbiosName, $forestMode, $safeModePassword)

	$featureLogPath = "c:\temp\featurelog.txt"
	New-Item $featureLogPath -ItemType file -Force
	$addsTools = "RSAT-AD-Tools"
	Add-WindowsFeature $addsTools
	Get-WindowsFeature | Where installed >>$featureLogPath

	Add-WindowsFeature -Name "ad-domain-services" -IncludeAllSubFeature -IncludeManagementTools
	Add-WindowsFeature -Name "dns" -IncludeAllSubFeature -IncludeManagementTools
	Add-WindowsFeature -Name "gpmc" -IncludeAllSubFeature -IncludeManagementTools 

	Get-WindowsFeature | Where installed >>$featureLogPath

	Import-Module ADDSDeployment
	Install-ADDSForest -CreateDnsDelegation:$false `
		-SafeModeAdministratorPassword (ConvertTo-SecureString $safeModePassword -asPlainText -Force) `
		-DatabasePath "C:\Windows\NTDS" `
		-DomainMode $forestMode `
		-DomainName $domainName `
		-DomainNetbiosName $netBiosName `
		-ForestMode $forestMode `
		-InstallDns:$true `
		-LogPath "C:\Windows\NTDS" `
		-NoRebootOnCompletion:$false `
		-SysvolPath "C:\Windows\SYSVOL" `
		-Force:$true
}

$remoteWin = newRemoteWin $ip $guestUser $guestPassword
try {
	invoke-command -ScriptBlock $createNewForest -session $remoteWin.session -EA stop -argumentlist $domainName, $netBiosName, $forestMode, $safeModePassword
} catch {
	writeCustomizedMsg "Fail - create AD forest"
	writeStderr
	[Environment]::exit("0")
}
writeCustomizedMsg "Success - create AD forest"