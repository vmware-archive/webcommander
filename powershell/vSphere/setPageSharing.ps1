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
        Set inter-VM transparent page sharing

	.DESCRIPTION
        This command sets inter-VM transparent page sharing on ESX or vCenter server.
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
		$serverPassword=$env:defaultPassword,
		
	[parameter(
		HelpMessage="Enable or disable this setting"
	)]
	[ValidateSet(
		"Disable",
		"Enable"
	)]
	[string]
		$switch="Disable"
)

foreach ($paramKey in $psboundparameters.keys) {
	$oldValue = $psboundparameters.item($paramKey)
	$newValue = [System.Net.WebUtility]::urldecode("$oldValue")
	set-variable -name $paramKey -value $newValue
}

. .\objects.ps1

$serverAddressList = $serverAddress.split(",") | %{$_.trim()}
foreach ($serverAddress in $serverAddressList) {
	$server = newServer $serverAddress $serverUser $serverPassword
	$vmHost = get-VMHost -Server $server.viserver
	foreach ($h in $vmHost)
	{
		try {
			if ($switch -eq "Enable") {
				$h | Set-VMHostAdvancedConfiguration -Name Mem.ShareScanGHz -Value 4 -Confirm:$false
			} else {
				$h | Set-VMHostAdvancedConfiguration -Name Mem.ShareScanGHz -Value 0 -Confirm:$false
			}
			writeCustomizedMsg "Success - configure page sharing for vmhost $($h.name)"
		} catch {
			writeCustomizedMsg "Fail - configure page sharing for vmhost $($h.name)"
			writeStderr
		}	
	}
}