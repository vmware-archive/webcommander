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
        Add linked clone pool

	.DESCRIPTION
        This command adds a linked clone pool on a broker.
		
	.FUNCTIONALITY
		Broker
	
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
		HelpMessage="Name of broker VM or IP / FQDN of broker machine"
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
		HelpMessage="IP / FQDN of VC server"
	)]
	[string]
		$vcAddress,  
	
	[parameter(
		Mandatory=$true,
		HelpMessage="Composer domain name"
	)]
	[string]
		$composerDomainName, 
	
	[parameter(
		Mandatory=$true,
		HelpMessage="Pool ID"
	)]
	[string]
		$poolId, 
	
	[parameter(
		HelpMessage="Name prefix, default is 'poolID-'"
	)]
	[string]	
		$namePrefix, 
	
	[parameter(
		Mandatory=$true,
		HelpMessage="Path to a virtual machine to be used as the parent VM for this desktop pool."
	)]
	[string]
		$parentVmPath, 
	
	[parameter(
		Mandatory=$true,
		HelpMessage="Path to the snapshot that is to be used as the image for this pool, i.e. /clean or /clean/test0"
	)]
	[string]
		$parentSnapshotPath, 
	
	[parameter(
		Mandatory=$true,
		HelpMessage="Specify a location for this new directory as a vCenter folder path."
	)]
	[string]
		$vmFolderPath, 
		
	[parameter(
		Mandatory=$true,
		HelpMessage="Path to a resource pool to be used for this desktop pool."
	)]
	[string]
		$resourcePoolPath, 
	
	[parameter(
		Mandatory=$true,
		HelpMessage="List of datastore specs for storage of desktop VMs and data disks, separated by semicolons using the format: '[Overcommit,usage]/path/to/datastore'"
	)]
	[string]
		$datastoreSpecs,
	
	[parameter(
		HelpMessage="Data disk letter, default is 'U'"
	)]
	[string]
		$dataDiskLetter="U", 
	
	[parameter(
		HelpMessage="Data disk size, default is 2048"
	)]
	[string]
		$dataDiskSize=2048, 
	
	[parameter(
		HelpMessage="Temp disk size, default is 1024"
	)]
	[string]
		$tempDiskSize=1024,
	
	[parameter(
		Mandatory=$true,
		HelpMessage="Minimum number of desktops to be provisioned in this pool."
	)]
	[string]
		$min, 
	
	[parameter(
		Mandatory=$true,
		HelpMessage="Maximum number of desktops to be provisioned in this pool."
	)]
	[string]
		$max, 
	
	[parameter(
		Mandatory=$true,
		HelpMessage="Pool type"
	)]
	[ValidateSet(
		"Persistent",
		"NonPersistent"
	)]
	[string]
		$poolType="Persistent"
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

if (!$namePrefix) {$namePrefix = $poolId + "-"}

$remoteWinBroker = newRemoteWinBroker $ip $guestUser $guestPassword
$remoteWinBroker.initialize()
$remoteWinBroker.addLinkedClonePool($vcAddress, $composerDomainName, $poolId, $namePrefix, 
	$parentVmPath, $parentSnapshotPath, $vmFolderPath, $resourcePoolPath, $datastoreSpecs, 
	$dataDiskLetter, $dataDiskSize, $tempDiskSize, $min, $max, $poolType)