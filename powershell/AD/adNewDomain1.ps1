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
	[string]$serverAddress, 
	$serverUser="root", 
	$serverPassword=$env:defaultPassword, 
	$vmName, 
	$guestUser="administrator", 
	$guestPassword=$env:defaultPassword,  
	$domainName, 
	$domainMode, 
	$safeModePassword=$env:defaultPassword,
	$parentDomainName, 
	$parentDomainUser="administrator", 
	$parentDomainPassword=$env:defaultPassword, 
	$parentDomainControllerAddress
)

foreach ($paramKey in $psboundparameters.keys) {
	$oldValue = $psboundparameters.item($paramKey)
	$newValue = [system.web.httputility]::urldecode("$oldValue")
	set-variable -name $paramKey -value $newValue
}

. .\objects.ps1

if (verifyIp($vmName)) {
	$ip = $vmName
} else {
	$server = newServer $serverAddress $serverUser $serverPassword
	$vm = newVmWin $server $vmName $guestUser $guestPassword
	$vm.waitfortools()
	$ip = $vm.getIPv4()
	$vm.enablePsRemote()
}

$remoteWin = newRemoteWin $ip $guestUser $guestPassword
try {
	invoke-command -FilePath ".\ad\adNewDomain2.ps1" -session $remoteWin.session -EA stop -argumentlist `
		$domainName, $domainMode, $safeModePassword, $parentDomainName, $parentDomainUser, `
		$parentDomainPassword, $parentDomainControllerAddress
} catch {
	writeCustomizedMsg "Fail - create AD domain"
	writeStderr
	[Environment]::exit("0")
}
writeCustomizedMsg "Success - create AD domain"