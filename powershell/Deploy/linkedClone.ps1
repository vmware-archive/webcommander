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
		Linked clone VM
		
	.DESCRIPTION
		This command creates linked clone VMs.
		If multiple vm hosts and datastores are provided, new VMs will be
		averagely distributed on them.
	
	.FUNCTIONALITY
		MakeVM
	
	.NOTES
		AUTHOR: Jerry Liu
		EMAIL: liuj@vmware.com
#>

Param (
	[parameter(
		Mandatory=$true,
		HelpMessage="IP or FQDN of VC server where the parent VM is located"
	)]
	[string]$vcAddress, 
	
	[parameter(
		HelpMessage="User name of VC server (default is administrator)"
	)]
	[string]
		$vcUser="administrator",
		
	[parameter(
		HelpMessage="Password of the user"
	)]
	[string]
		$vcPassword=$env:defaultPassword,  
	
	[parameter(
		Mandatory=$true,
		HelpMessage="Name of the parent VM"
	)]
	[string]
		$parentVmName, 
	
	[parameter(
		Mandatory=$true,
		HelpMessage="Name of the parent snapshot"
	)]
	[string]
		$parentSnapshotName, 
	
	[parameter(
		Mandatory=$true,
		HelpMessage="Datastore name. Support multiple values seperated by comma.
			Also support powershell expression."
	)]
	[string]
		$datastoreName, 
	
	[parameter(
		Mandatory=$true,
		HelpMessage="VM host name. Support multiple values seperated by comma.
			Also support powershell expression."
	)]
	[string]
		$vmHostName,
	
	[parameter(
		Mandatory=$true,
		HelpMessage="New VM name. Support multiple values seperated by comma.
			Also support powershell expression."
	)]
	[string]
		$newVmName
)

foreach ($paramKey in $psboundparameters.keys) {
	$oldValue = $psboundparameters.item($paramKey)
	$newValue = [system.web.httputility]::urldecode("$oldValue")
	set-variable -name $paramKey -value $newValue
}

. .\objects.ps1

$vmHostList = parseInput $vmHostName
$datastoreList = parseInput $datastoreName
$newVmList = parseInput $newVmName 

add-pssnapin vm* -ea silentlycontinue

try {
	$vc = connect-VIServer $vcAddress -user $vcUser -password $vcPassword -wa 0 -EA stop
	$vm = get-vm -name $parentVmName
	$snapshot = get-snapshot -name $parentSnapshotName -vm $vm -wa 0 -EA stop
	$vmHost = get-vmHost -name $vmHostList -wa 0 -EA stop
	$datastore = get-datastore -name $datastoreList -wa 0 -EA stop
} catch {
	writeCustomizedMsg "Fail - retrieve resource for creating linked clone VM"
	writeStderr
	[Environment]::exit("0")
}

$j = 0
$k = 0
foreach ($vmName in $newVmList) {
	try {
		$newVm = New-VM -name $vmName -VM $vm -LinkedClone -ReferenceSnapshot $snapshot -ResourcePool $vmHost[$j] -Datastore $datastore[$k] -wa 0 -EA stop
		start-vm $newVm
		writeCustomizedMsg "Success - create linked clone VM $vmName"
	} catch {
		writeCustomizedMsg "Fail - create linked clone VM $vmName"
		writeStderr
	}	
	$j++
	if ($j -eq $vmHost.count) {$j = 0}
	$k++
	if ($k -eq $datastore.count) {$k = 0}
}