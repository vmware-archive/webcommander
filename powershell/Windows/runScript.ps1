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
	$guestUser=".\administrator", 
	$guestPassword=$env:defaultPassword,   
	$script,
	$type="Bat"
)

foreach ($paramKey in $psboundparameters.keys) {
	$oldValue = $psboundparameters.item($paramKey)
	$newValue = [system.web.httputility]::urldecode("$oldValue")
	set-variable -name $paramKey -value $newValue
}

. .\objects.ps1

function runScript {
	param ($ip, $guestUser, $guestPassword, $script, $type)
	$remoteWin = newRemoteWin $ip $guestUser $guestPassword

	if ($type -eq "Powershell") {
		$result = $remoteWin.executePsTxtRemote($script, "run powershell script in VM")
	} elseif ($type -eq "interactive"){
		$result = $remoteWin.runInteractiveCmd($script)
	} elseif ($type -eq "interactivePs1"){
		$result = $remoteWin.runInteractivePs1($script)
	} else {
		$script | set-content "..\www\upload\$ip.txt"
		$remoteWin.sendFile("..\www\upload\$ip.txt", "c:\temp\script.bat")
		$script = "Invoke-WmiMethod -path win32_process -name create -argumentlist 'c:\temp\script.bat'"
		$result = $remoteWin.executePsTxtRemote($script, "trigger batch script in VM")
	}
	writeStdout($result)
}

$vmList = $vmName.split(",") | %{$_.trim()}	
foreach ($vmName in $vmList) {
	if (verifyIp($vmName)) {
		$ip = $vmName
		writeCustomizedMsg "Info - remote machine is $ip"
		runScript $ip $guestUser $guestPassword $script $type
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
			writeCustomizedMsg "Info - VM name is $($vm.name)"
			if ($type -eq "bash") {
				$result = $vm.runScript($script, "Bash")
				writeStdout($result)
			} else {
				$ip = $vm.getIPv4()
				$vm.enablePsRemote()
				$vm.enableCredSSP()
				runScript $ip $guestUser $guestPassword $script $type
			}
		}
	}
	writeSeperator
}
get-pssession | remove-pssession