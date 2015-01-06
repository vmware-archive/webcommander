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
        Remove NFS datastore

	.DESCRIPTION
        This command remove NFS storage on ESX hosts managed by a vCenter server.
		If cluster is defined, only ESX hosts in the cluster are selected.
		If storageName, nfsHost and path are not defined, all NFS storage are removed.
		Otherwise, only matched ones are removed.
		
	.FUNCTIONALITY
		vSphere
		
	.NOTES
		AUTHOR: Jerry Liu
		EMAIL: liuj@vmware.com
#>

Param (	
	[parameter(
		Mandatory=$true,
		HelpMessage="IP or FQDN of the ESX or VC server"
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
		HelpMessage="IP / FQDN of NFS server"
	)]
	[string]
		$nfsHost,
		
	[parameter(
		HelpMessage="Remote path of the NFS mount point"
	)]
	[string]
		$path,
	
	[parameter(
		HelpMessage="Name for the new datastore"
	)]
	[string]
		$storageName
)

foreach ($paramKey in $psboundparameters.keys) {
	$oldValue = $psboundparameters.item($paramKey)
	$newValue = [system.web.httputility]::urldecode("$oldValue")
	set-variable -name $paramKey -value $newValue
}

. .\objects.ps1

$serverAddressList = $serverAddress.split(",") | %{$_.trim()}
$clusterList = $cluster.split(",") | %{$_.trim()}
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
	$datastore = get-datastore | ?{$_.type -eq "nfs"}
	if ($storageName) {$datastore = $datastore | ?{$_.name -eq $storagename}}
	if ($nfsHost) {$datastore = $datastore | ?{$_.remotehost -eq $nfsHost}}
	if ($path) {$datastore = $datastore | ?{$_.remotepath -eq $path}}
	if ($datastore) {
		foreach ($esx in $vmHosts) {
			try {
				remove-datastore -vmhost $esx -datastore $datastore -confirm:$false
				writeCustomizedMsg "Success - remove NFS share $datastore on host $esx"
			} catch {
				writeCustomizedMsg "Fail - remove NFS share $datastore on host $esx"
				writeStderr
			}
		}
	} else {
		writeCustomizedMsg "Info - no NFS share found"
	}
	disconnect-VIServer -Server * -Force -Confirm:$false
} 	