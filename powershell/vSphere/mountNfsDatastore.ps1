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
        Mount NFS datastore

	.DESCRIPTION
        This command mount NFS storage on ESX hosts managed by a vCenter server.
		If cluster is defined, only ESX hosts in the cluster are selected.
		
	.FUNCTIONALITY
		vSphere
#>

## Author: Jerry Liu, liuj@vmware.com

Param (	
	[parameter(
		Mandatory=$true,
		HelpMessage="IP or FQDN of the ESX or VC server. Support multiple values seperated by comma."
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
		HelpMessage="Name of cluster. If defined, only ESX hosts in the cluster are selected"
	)]
	[string]
		$cluster,
	
	[parameter(
		Mandatory=$true,
		HelpMessage="IP / FQDN of NFS server. Support multiple values seperated by comma."
	)]
	[string]
		$nfsHost,
		
	[parameter(
		Mandatory=$true,
		HelpMessage="Remote path of the NFS mount point. Support multiple values seperated by comma."
	)]
	[string]
		$path,
	
	[parameter(
		Mandatory=$true,
		HelpMessage="Name for the new datastore. Support multiple values seperated by comma."
	)]
	[string]
		$storageName,
		
	[parameter(
		HelpMessage="Mount NFS read only"
	)]
	[ValidateSet(
		"false",
		"true"
	)]
		$readOnly="false"
)

foreach ($paramKey in $psboundparameters.keys) {
	$oldValue = $psboundparameters.item($paramKey)
	$newValue = [system.web.httputility]::urldecode("$oldValue")
	set-variable -name $paramKey -value $newValue
}

. .\objects.ps1

$nfsHostList = $nfsHost.split(",") | %{$_.trim()}
$pathList = $path.split(",") | %{$_.trim()}
$storageNameList = $storageName.split(",") | %{$_.trim()}
if (($nfsHostList.count -ne $pathList.count) -or ($nfsHostList.count -ne $storageNameList.count)) {
	writeCustomizedMsg "Fail - number of nfsHost, path and storageName don't match"
	[Environment]::exit("0")
}
$serverAddressList = $serverAddress.split(",") | %{$_.trim()}
$clusterList = $cluster.split(",") | %{$_.trim()}
$readOnly = [System.Convert]::ToBoolean("$readOnly")
add-pssnapin vmware.vimautomation.core -ea silentlycontinue

foreach ($address in $serverAddressList) {
	try {
		connect-VIServer $address -user $serverUser -password $serverPassword -wa 0 -EA stop | out-null
	} catch {
		writeCustomizedMsg "Fail - connect to server $address"
		writeStderr
		[Environment]::exit("0")
	}
	if ($clusterList) {
		$vmHosts = get-vmhost -location (get-cluster $clusterList)
	} else {
		$vmHosts = get-vmhost
	}
	$vmHosts | Get-VMHostFirewallException -Name "NFS Client" | Set-VMHostFirewallException -Enabled:$true | out-null
	$vmHosts | Get-EsxCli | %{try{$_.network.firewall.ruleset.set($true, $true, "nfsClient")}catch{}} | out-null
	foreach ($esx in $vmHosts) {
		for ($i=0;$i -lt $pathList.count; $i++) {
			try {
				new-datastore -nfs -vmHost $esx -name $storageNameList[$i] -path $pathList[$i] -nfshost $nfsHostList[$i] -readOnly:$readOnly -EA Stop
				writeCustomizedMsg "Success - mount NFS share on host $($esx.name)."
			} catch [VMware.VimAutomation.ViCore.Types.V1.ErrorHandling.AlreadyExists] {
				writeCustomizedMsg "Info - NFS share already exists on host $($esx.name)."
			} catch {
				writeCustomizedMsg "Fail - mount NFS share on host $($esx.name)."
				writeStderr
			}
		}
	}
	disconnect-VIServer -Server * -Force -Confirm:$false
} 	