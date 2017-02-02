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
        Add adapter to distributed switch

	.DESCRIPTION
        This command adds a physical network adapter to a distributed switch.
		This command could configure multiple ESX hosts controlled by multiple VC servers. 
		If no specific ESX is defined, all of them are affected.
	
	.FUNCTIONALITY
		vSphere
		
	.NOTES
		AUTHOR: Jerry Liu
		EMAIL: liuj@vmware.com
#>

Param (
	[parameter(
		Mandatory=$true,
		HelpMessage="IP or FQDN of the VC server"
	)]
	[string]
		$vcAddress,
	
	[parameter(
		HelpMessage="User name to connect to the server (default is administrator)"
	)]
	[string]	
		$vcUser="administrator", 
	
	[parameter(
		HelpMessage="Password of the user"
	)]
	[string]	
		$vcPassword=$env:defaultPassword,
	
	[parameter(
		HelpMessage="FQDN or IP of ESX host. Support multiple values seperated by comma. Default is '*'"
	)]
	[string]	
		$esxAddress='*',
	
	[parameter(
		Mandatory=$true,
		HelpMessage="Name distributed switch"
	)]
	[string]
		$dsName,
	
	[parameter(
		Mandatory=$true,
		HelpMessage="Name of physical network adapter"
	)]
	[string]
		$nicName
)

foreach ($paramKey in $psboundparameters.keys) {
	$oldValue = $psboundparameters.item($paramKey)
	$newValue = [System.Net.WebUtility]::urldecode("$oldValue")
	set-variable -name $paramKey -value $newValue
}

. .\objects.ps1

$esxAddressList = $esxAddress.split(",") | %{$_.trim()}
$vcAddressList = $vcAddress.split(",") | %{$_.trim()}
foreach ($vcAddress in $vcAddressList) {
	$vc = newServer $vcAddress $serverUser $serverPassword 
	$ds = get-VDSwitch -name $dsName -server $vc.viserver
	get-vmhost -name $esxAddressList -server $vc.viserver -ea stop | % {
		try {
			$vmhostNetworkAdapter = $_ | Get-VMHostNetworkAdapter -Physical `
				-Name $nicName -ea Stop
			$ds | Add-VDSwitchPhysicalNetworkAdapter -VMHostNetworkAdapter `
				$vmhostNetworkAdapter -confirm:$false -ea Stop
			writeCustomizedMsg "Success - add physical NIC to distributed switch on ESX $_"
		} catch {
			writeCustomizedMsg "Fail - add physical NIC to distributed switch on ESX $_"
			writeStderr
		}
	}
}