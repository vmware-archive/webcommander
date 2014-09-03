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
	$cert
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

$remoteWinBroker = newRemoteWin $ip $guestUser $guestPassword

$remoteWinBroker.sendFile("$cert", "C:\temp\certnew.cer")
$script = {
	remove-item c:\temp\trust.key -ea silentlyContinue
	& "C:\Program Files\VMware\VMware View\Server\jre\bin\keytool.exe" -import -alias alias -file C:\temp\certnew.cer -keystore c:\temp\trust.key -storepass 111111 -noprompt 2>null
	copy-item c:\temp\trust.key "C:\Program Files\VMware\VMware View\Server\sslgateway\conf\" 
	$content = @"
trustKeyfile=trust.key
trustStoretype=JKS
useCertAuth=true
"@
	#$content | out-file "c:\Program Files\VMware\VMware View\Server\sslgateway\conf\locked.properties" -encoding UTF8
	$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding($False)
	[System.IO.File]::WriteAllLines("c:\Program Files\VMware\VMware View\Server\sslgateway\conf\locked.properties", $content, $Utf8NoBomEncoding)
	restart-service wsbroker
}

try {
	$result = invoke-command -scriptBlock $script -session $remoteWinBroker.session -EA stop
} catch {
	writeCustomizedMsg "Fail - setup smartcard"
	writeStderr
	[Environment]::exit("0")
}

# $remoteWinBroker.sendFile("..\www\download\smartcard.zip", "C:\temp\")
# $script = {
	# remove-item -path "c:\temp\smartcard" -recurse -force -confirm:$false -ea silentlyContinue
	# $shell = new-object -com shell.application
	# $zip = $shell.namespace("c:\temp\smartcard.zip") 
	# $destination = $shell.namespace("c:\temp") 
	# $destination.Copyhere($zip.items(),20) 
	# $cmd = "c:\temp\smartcard\ActivClient_x64_6.2.msi"
	# $installprocess = [System.Diagnostics.Process]::Start($cmd, " /quiet")
	# $installprocess.WaitForExit()
	# $cmd = "rundll32.exe"
	# $cmdPara = " advpack.dll,LaunchINFSectionEx C:\temp\smartcard\gemalto\Gemalto.MiniDriver.NET.inf,,,256"
	# $installprocess = [System.Diagnostics.Process]::Start($cmd, $cmdPara)
	# $installprocess.WaitForExit()
# }
# try {
	# $result = invoke-command -scriptBlock $script -session $remoteWinBroker.session -EA stop
# } catch {
	# writeCustomizedMsg "Fail - configure smartcard drivers"
	# writeStderr
	# [Environment]::exit("0")
# }

#$result = $remoteWinBroker.runInteractivePs1($script)
writeStdout($result)
writeCustomizedMsg "Success - setup smartcard"
# $remoteWinBroker.restart()