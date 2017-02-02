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
        List resource pools

	.DESCRIPTION
        This command lists all resource pools on ESX or vCenter server.
		This command could execute against multiple servers.
		
	.FUNCTIONALITY
		vSphere
		
	.NOTES
		AUTHOR: Jerry Liu
		EMAIL: liuj@vmware.com
#>

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
		$serverPassword=$env:defaultPassword
)

foreach ($paramKey in $psboundparameters.keys) {
	$oldValue = $psboundparameters.item($paramKey)
	$newValue = [System.Net.WebUtility]::urldecode("$oldValue")
	set-variable -name $paramKey -value $newValue
}

. .\objects.ps1

Function listResourcePool{
	param([parameter(valueFromPipeLine=$true)]$resourcePool)
	process {
		foreach ($r in $resourcePool) {
			$name = $r.name
			$id = $r.id
			$path = $r.name
			Do { $parent = $r.parent
				$path = $parent.Name + "\" + $path
				$r = $parent
			} While ($parent)
			write-output "<resourcepool>"
			write-output "<name>$name</name>"
			write-output "<id>$id</id>"
			write-output "<path>$path</path>"
			write-output "</resourcepool>"
		}
	}
}

$serverAddressList = $serverAddress.split(",") | %{$_.trim()}
foreach ($serverAddress in $serverAddressList) {
	$server = newServer $serverAddress $serverUser $serverPassword
	$resourcePool = get-resourcepool -Server $server.viserver
	$resourcePool | sort | listResourcePool
}