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
	$packageUrl="https://github.com/vmware/webcommander/archive/master.zip",
	$authentication="windows",
	$defaultPassword=$env:defaultPassword
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
$remoteWin.sendFile("..\setup.ps1","c:\temp\setup.ps1")
$cmd = "c:\temp\setup.ps1 '$packageUrl' '$authentication' '$guestPassword' '$defaultPassword'"
$result = $remoteWin.executePsTxtRemote($cmd, "trigger setup script in remote machine")
writeStdout $result
# try {
	# Write-Output "<stdOutput><![CDATA["
	# invoke-command -FilePath "..\setup.ps1" `
		# -argumentlist $packageUrl, $authentication, $guestPassword, $defaultPassword `
		# -session $remoteWin.session -EA stop -outvariable $result | out-null
	# Write-Output "]]></stdOutput>"
# } catch {
	# writeCustomizedMsg "Fail - install WebCommander"
	# writeStderr
	# [Environment]::exit("0")
# }

if (($result -match "WebCommander website updated successfully") `
	-or ($result -match "WSMAN settings changed successfully")) {
	writeCustomizedMsg "Success - install WebCommander"
} else {
	writeCustomizedMsg "Fail - install WebCommander"
}