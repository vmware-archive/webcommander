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
        Deploy OVA to vCenter

	.DESCRIPTION
        This command deploy an OVA to virtual center server.
		
	.FUNCTIONALITY
		OVA
	
	.NOTES
		AUTHOR: Jerry Liu
		EMAIL: liuj@vmware.com
#>

Param (
	[parameter(
		Mandatory=$true,
		HelpMessage="IP or FQDN of VC server to which the OVA will be deployed"
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
		HelpMessage="Name of datacenter to which the OVA will be deployed"
	)]
	[string]
		$datacenter,
	
	[parameter(
		HelpMessage="Name of cluster to which the OVA will be deployed"
	)]
	[string]	
		$cluster, 
		
	[parameter(
		HelpMessage="Name of ESX host to which the OVA will be deployed"
	)]
	[string]	
		$esxHost, 
		
	[parameter(
		HelpMessage="Name of datastore to which the OVA will be deployed"
	)]
	[string]
		$datastore, 
	
	[parameter(
		HelpMessage="Storage format"
	)]
	[ValidateSet(
		"Thin",
		"Thick",
		"EagarZeroedThick"
	)]
	[string]
		$storageFormat,
		
	[parameter(
		HelpMessage="Name of Virtual Machine Port Group to which the OVA will connect"
	)]
	[string]
		$portGroup,
		
	[parameter(
		HelpMessage="Advanced properties, such as --prop:vami.hostname=myvmname"
	)]
	[string]
		$advancedProperty, 
		
	[parameter(
		Mandatory=$true,
		HelpMessage="URL of the OVA"
	)]
	[string]
		$ovaUrl, 
		
	[parameter(
		Mandatory=$true,
		HelpMessage="Name of the VM to be deployed"
	)]
	[string]
		$vmName
)

foreach ($paramKey in $psboundparameters.keys) {
	$oldValue = $psboundparameters.item($paramKey)
	$newValue = [System.Net.WebUtility]::urldecode("$oldValue")
	set-variable -name $paramKey -value $newValue
}

. .\objects.ps1

if (!$datastore -or !$portGroup -or !$esxHost) {
	add-pssnapin vm* -ea silentlyContinue
	connect-viserver $vcAddress -user $vcUser -password $vcPassword
	$container = get-datacenter $datacenter
	if ($cluster) { $container = get-cluster $cluster -location $container}
	if (!$esxHost) { 
		$vmhost = get-vmhost -location $container | select -first 1
	} else {
		$vmhost = get-vmhost -name $esxHost -location $container
	}
	if (!$datastore) { $datastore = (get-datastore -vmhost $vmhost | sort freespacegb -desc | select -first 1).name } 
	if (!$portGroup) { $portgroup = (get-virtualportgroup -vmhost $vmhost | ?{$_.port -eq $null} | select -first 1).name }
}

$cmd = "& `"C:\Program Files\VMware\VMware OVF Tool\ovftool.exe`" --acceptAllEulas --allowAllExtraConfig --hideEula --noSSLVerify --datastore=`"$datastore`" --diskMode=$storageFormat --network=`"$portGroup`" --name=`"$vmName`""
if ($advancedProperty) {
	$advancedProperty = $advancedProperty.replace("`r`n"," ")
	$cmd += " $advancedProperty"
}
$viPath = "vi://$vcUser`:$vcPassword@$vcAddress/$datacenter/host/"
if($cluster) {
	$viPath += "$cluster/"
}
if($esxHost) {
	$viPath += "$esxHost/"
} else {
	$viPath += "$($vmhost.name)/"
}
$cmd += " `"$ovaUrl`" `"$viPath`""
writeCustomizedMsg "Info - start to deploy OVA"
try {
	$output = invoke-expression $cmd -EA stop
	if ($output -notcontains "Completed successfully") {
		throw $output
	} else {
		writeCustomizedMsg "Success - deploy OVA"
	}
} catch {
	writeCustomizedMsg "Fail - deploy OVA"
	writeStderr
	[Environment]::exit("0")
}