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
	$vcAddress,
	$vcUser="administrator", 
	$vcPassword=$env:defaultPassword,
	$esxAddress='*',
	$portGroup
)

foreach ($paramKey in $psboundparameters.keys) {
	$oldValue = $psboundparameters.item($paramKey)
	$newValue = [system.web.httputility]::urldecode("$oldValue")
	set-variable -name $paramKey -value $newValue
}

. .\objects.ps1

add-pssnapin vmware.vimautomation.core -ea silentlycontinue
try {
	connect-VIServer $vcAddress -user $vcUser -password $vcPassword -wa 0 -EA stop
} catch {
	writeCustomizedMsg "Fail - connect to server $address"
	writeStderr
	[Environment]::exit("0")
}
$esxAddressList = $esxAddress.split(",") | %{$_.trim()}
try {
	$pg = get-virtualPortGroup -name $portGroup -ea Stop
	$vSwitch = $pg.virtualSwitch
	get-vmhost $esxAddressList -ea stop | % {
		New-VMHostNetworkAdapter -vmhost $_ -PortGroup $portGroup -VirtualSwitch $vSwitch `
			-VsanTrafficEnabled:$true -confirm:$false -consoleNic:$false -ea Stop
		writeCustomizedMsg "Success - add host network adapter for VSAN on ESX $_"
	}
} catch {
	writeCustomizedMsg "Fail - add host network adapter for VSAN on ESX $_"
	writeStderr
	[Environment]::exit("0")
}
disconnect-VIServer -Server * -Force -Confirm:$false