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
        Create a child domain

	.DESCRIPTION
        This command creates a child domain in AD.
		
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
		HelpMessage="Name of the new domain to create"
	)]
	[string]
		$domainName, 
	
	[parameter(
		Mandatory=$true,
		HelpMessage="Domain mode"
	)]
	[ValidateSet(
		"Win2003",
		"Win2008",
		"Win2008R2",
		"Win2012"
	)]
	[string]
		$domainMode,
		
	[parameter(
		HelpMessage="Safe mode administrator password"
	)]
	[string]
		$safeModePassword=$env:defaultPassword,
		
	[parameter(
		Mandatory=$true,
		HelpMessage="Name of the parent domain"
	)]
	[string]
		$parentDomainName, 
		
	[parameter(
		HelpMessage="User of the parent domain (default is administrator)"
	)]
	[string]
		$parentDomainUser="administrator", 
		
	[parameter(
		HelpMessage="Password of the parent domain"
	)]
	[string]
		$parentDomainPassword=$env:defaultPassword, 
		
	[parameter(
		Mandatory=$true,
		HelpMessage="FQDN of the parent domain controller"
	)]
	[string]
		$parentDomainControllerAddress
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

$createNewDomain = {
	Param (
		$domainName, 
		$domainMode, 
		$safeModePassword,
		$parentDomainName, 
		$parentDomainUser, 
		$parentDomainPassword, 
		$parentDomainControllerAddress
	)

	$parentDomainCred = new-object -typeName System.management.automation.pscredential -argumentList `
		"$parentDomainUser@$parentDomainName", (ConvertTo-SecureString "$parentDomainPassword" -asPlainText -Force)

	$featureLogPath = "c:\temp\featurelog.txt"
	New-Item $featureLogPath -ItemType file -Force | out-null
	$addsTools = "RSAT-AD-Tools"
	Add-WindowsFeature $addsTools | out-null
	Get-WindowsFeature | Where installed >>$featureLogPath

	Add-WindowsFeature -Name "ad-domain-services" -IncludeAllSubFeature -IncludeManagementTools | out-null
	Add-WindowsFeature -Name "dns" -IncludeAllSubFeature -IncludeManagementTools | out-null
	Add-WindowsFeature -Name "gpmc" -IncludeAllSubFeature -IncludeManagementTools | out-null 

	Get-WindowsFeature | Where installed >>$featureLogPath

	Import-Module ADDSDeployment
	Install-ADDSDomain -Credential $parentDomainCred `
		-NewDomainName $domainName `
		-ParentDomainName $parentDomainName `
		-ReplicationSourceDC $parentDomainControllerAddress `
		-InstallDns:$true `
		-CreateDnsDelegation:$true `
		-DatabasePath "C:\Windows\NTDS" `
		-DomainMode $domainMode `
		-SafeModeAdministratorPassword (ConvertTo-SecureString $safeModePassword -asPlainText -Force) `
		-LogPath "C:\Windows\NTDS" `
		-NoRebootOnCompletion:$false `
		-SysvolPath "C:\Windows\SYSVOL" `
		-Force:$true
}

$remoteWin = newRemoteWin $ip $guestUser $guestPassword
try {
	invoke-command -ScriptBlock $createNewDomain -session $remoteWin.session -EA stop -argumentlist `
		$domainName, $domainMode, $safeModePassword, $parentDomainName, $parentDomainUser, `
		$parentDomainPassword, $parentDomainControllerAddress
} catch {
	writeCustomizedMsg "Fail - create AD domain"
	writeStderr
	[Environment]::exit("0")
}
writeCustomizedMsg "Success - create AD domain"