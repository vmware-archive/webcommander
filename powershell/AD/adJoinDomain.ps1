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

## Author: Jerry Liu, liuj@vmware.com

Param (
	$serverAddress, 
	$serverUser="root", 
	$serverPassword=$env:defaultPassword, 
	$vmName, 
	$guestUser="administrator", 
	$guestPassword=$env:defaultPassword,
	$domainName,
	$domainUser="administrator",
	$domainPassword=$env:defaultPassword,
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

$vmNameList = $vmName.split(",") | %{$_.trim()}	
foreach ($vmName in $vmNameList) {
	if (verifyIp($vmName)) {
		$ip = $vmName
		writeCustomizedMsg "Info - remote machine is $ip"
		joinDomain $ip $guestUser $guestPassword $domainName $domainUser $domainPassword $dnsIp
	} else {
		if (!$server) {
			$server = newServer $serverAddress $serverUser $serverPassword
		}
		$vmList = get-vm -name "$vmName" -server $server.viserver -EA SilentlyContinue
		if (!$vmList) {
			writeCustomizedMsg "Fail - get VM $vmName"
			[Environment]::exit("0")
		}
		$vmList | % { 
			$vm = newVmWin $server $_.name $guestUser $guestPassword
			$vm.waitfortools()
			$ip = $vm.getIPv4()
			$vm.enablePsRemote()
			writeCustomizedMsg "Info - VM name is $($vm.name)"
			joinDomain $ip $guestUser $guestPassword $domainName $domainUser $domainPassword $dnsIp
			writeSeperator
		}	
	}	
}