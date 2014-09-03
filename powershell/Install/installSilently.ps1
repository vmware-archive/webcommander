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
	[string]$vmName, 
	$guestUser="administrator", 
	$guestPassword=$env:defaultPassword,  
	$ssName="", 
	$installerUrl, 
	$silentInstallParam,
	$downloadOnly="false"
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
	if ($ssName -ne "") {
		$vm.restoreSnapshot($ssName)
		$vm.start()
	}
	$vm.waitfortools()
	$ip = $vm.getIPv4()
	$vm.enablePsRemote()
}

$remoteWin = newRemoteWin $ip $guestUser $guestPassword

$installer = ($installerUrl.split("/"))[-1]

$cmd = "
	new-item c:\temp -type directory -force | out-null
	`$wc = new-object system.net.webclient;
	`$wc.downloadfile('$installerUrl', 'c:\temp\$installer');
	get-item 'c:\temp\$installer' -ea Stop | out-null
"
$remoteWin.executePsTxtRemote($cmd, "download file $installer", "1200")

if ($downloadOnly -eq "true") {
	[Environment]::exit("0")
}

$cmd = "	
	`$installprocess = [System.Diagnostics.Process]::Start('c:\temp\$installer', '$silentInstallParam')
	`$installprocess.WaitForExit()
	If ((0,3010) -notcontains `$installprocess.ExitCode) {    
		throw ('Fail to install $installer. Exit code:' + `$installprocess.ExitCode)
	}
"
$remoteWin.executePsTxtRemote($cmd, "install $installer", 2400)