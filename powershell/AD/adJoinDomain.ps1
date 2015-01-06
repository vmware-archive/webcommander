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
        Join domain

	.DESCRIPTION
        This command join Windows machines to a domain.
		
	.FUNCTIONALITY
		AD
	
	.NOTES
		AUTHOR: Jerry Liu
		EMAIL: liuj@vmware.com
#>

Param (
	[parameter(
		HelpMessage="IP or FQDN of the ESX or VC server where the target VM is located"
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
		HelpMessage="Name of the VM or IP / FQDN of remote Windows machine. Support multiple values seperated by comma. VM name and IP could be mixed."
	)]
	[string]
		$vmName,
	
	[parameter(
		HelpMessage="User of Windows machine (default is administrator)"
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
		HelpMessage="Name of the domain to join"
	)]
	[string]
		$domainName,
		
	[parameter(
		HelpMessage="User of the domain (default is administrator)"
	)]
	[string]
		$domainUser="administrator",
	
	[parameter(
		HelpMessage="Password of the domain user"
	)]
	[string]
		$domainPassword=$env:defaultPassword,
		
	[parameter(
		HelpMessage="IP address of DNS server"
	)]
	[string]
		$dnsIp
)

foreach ($paramKey in $psboundparameters.keys) {
	$oldValue = $psboundparameters.item($paramKey)
	$newValue = [system.web.httputility]::urldecode("$oldValue")
	set-variable -name $paramKey -value $newValue
}

. .\objects.ps1

function joinDomain {
	param ($ip, $guestUser, $guestPassword, $domainName, $domainUser, $domainPassword, $dnsIp)
	$remoteWin = newRemoteWin $ip $guestUser $guestPassword

	$cmd = "
		`$NICs = Get-WMIObject Win32_NetworkAdapterConfiguration | where{`$_.IPEnabled -eq 'TRUE'}
		Foreach(`$NIC in `$NICs) {
			`$NIC.SetDNSServerSearchOrder('$dnsIp')
		}
	"
	$remoteWin.executePsTxtRemote($cmd, "set DNS server IP")

	$cmd = "
		`$domainCred = new-object -typeName System.management.automation.pscredential -argumentList '$domainUser@$domainName', (ConvertTo-SecureString '$domainPassword' -asPlainText -Force)
		add-computer -domainname $domainName -credential `$domainCred -wa 0 -EA Stop
	"
	$remoteWin.executePsTxtRemote($cmd, "join machine to domain")
	$remoteWin.restart()
}		

$ipList = getVmIpList $vmName $serverAddress $serverUser $serverPassword
$ipList | % {
	joinDomain $_ $guestUser $guestPassword $domainName $domainUser $domainPassword $dnsIp
}