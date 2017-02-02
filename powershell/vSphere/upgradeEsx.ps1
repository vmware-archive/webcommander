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
    Upgrade ESX to a new build

	.DESCRIPTION
    This command ugrades an ESX server to a new build. 
		
	.FUNCTIONALITY
		vSphere
		
	.NOTES
		AUTHOR: Jerry Liu
		EMAIL: liuj@vmware.com
#>

Param (
	[parameter(
		Mandatory=$true,
		HelpMessage="IP or FQDN of the ESX server"
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
		HelpMessage="Build number"
	)]
	[string]
		$build
)

foreach ($paramKey in $psboundparameters.keys) {
	$oldValue = $psboundparameters.item($paramKey)
	$newValue = [System.Net.WebUtility]::urldecode("$oldValue")
	set-variable -name $paramKey -value $newValue
}

. .\objects.ps1

$serverIp = (get-netipaddress | ?{$_.InterfaceAlias -eq "ethernet" -and ($_.AddressFamily -eq "ipv4")})[0].IPAddress
$depot = "http://$serverIp/ESXi/$build/index.xml"
try {
	$xml = [xml](invoke-webrequest -uri $depot -UseBasicParsing).content
} catch {
	writeCustomizedMsg "Fail - find depot at $depot"
	writeStderr
	[Environment]::exit("0")
}

if ($xml.vendorlist) {
	writeCustomizedMsg "Success - verify depot"
	writeStdout $xml.innerXML
} else {
	writeCustomizedMsg "Fail - verify depot"
	[Environment]::exit("0")
}

add-pssnapin vmware.vimautomation.core -ea silentlycontinue

try {
	connect-VIServer $serverAddress -user $serverUser -password $serverPassword -wa 0 -EA stop
} catch {
	writeCustomizedMsg "Fail - connect to server $serverAddress"
	writeStderr
	[Environment]::exit("0")
}

try {
	get-VMHost | set-vmhost -state maintenance -ea Stop
	writeCustomizedMsg "Success - enter maintenance mode"
} catch {
	writeCustomizedMsg "Fail - enter maintenance mode"
	writeStderr
	[Environment]::exit("0")
}

try {
	Get-VMHost | Foreach {
		Start-VMHostService -HostService ($_ | Get-VMHostService | Where { $_.Key -eq "TSM-SSH"} ) -ea Stop
		writeCustomizedMsg "Success - enable SSH"
	}
} catch {
	writeCustomizedMsg "Fail - enable SSH"
	writeStderr
	[Environment]::exit("0")
}
	
$sshServer = newSshServer $serverAddress $serverUser $serverPassword

$cmd = "esxcli software sources profile list -d $depot"
$r = $sshServer.runCommand($cmd)

[string]$p = $r.split(' ').split("`n") | Select-String standard
$cmd = "esxcli software profile update -d $depot -p $p --no-sig-check --allow-downgrades --force"
$r = $sshServer.runCommand($cmd)
if ($r -match "The update completed successfully") {
	writeCustomizedMsg "Success - upgrade ESX"
} else {
	writeCustomizedMsg "Fail - upgrade ESX"
	write-host $r
	try {
		get-VMHost | set-vmhost -state connected
	} catch {
		writeCustomizedMsg "Fail - exit maintenance mode"
		writeStderr
		[Environment]::exit("0")
	}
	writeCustomizedMsg "Success - exit maintenance mode"
	[Environment]::exit("0")
}

try {
	get-VMHost | restart-vmhost -force -runAsync -confirm:$false
} catch {
	writeCustomizedMsg "Fail - restart vmhost"
	writeStderr
	[Environment]::exit("0")
}
writeCustomizedMsg "Success - restart vmhost"
disconnect-VIServer -Server * -Force -Confirm:$false

start-sleep 180

$flag = $false
$begin = get-date
$timeout = 600
$delay = 30
while (($flag -eq $false) -and ((get-date) -lt $begin.addseconds($timeout))) {
	$server = connect-VIServer $serverAddress -user $serverUser -password $serverPassword -wa 0 -EA silentlyContinue
	if ($server){
		$flag = $true
		try {
			get-VMHost | set-vmhost -state connected
		} catch {
			writeCustomizedMsg "Fail - exit maintenance mode"
			writeStderr
			[Environment]::exit("0")
		}
		writeCustomizedMsg "Success - exit maintenance mode"
	} else {
		start-sleep $delay
	}	
} 
if ($flag -eq $false) {
	writeCustomizedMsg "Fail - connect to server $serverAddress in $timeout seconds"
}