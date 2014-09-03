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
	$script,
	$type="Bat",
	$method="PSSession"
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
	if ($type -eq "bash") {
		$result = $vm.runScript($script, "Bash")
		writeStdout($result)
		[Environment]::exit("0")
	} 
	if ($method -eq "VMwareTools") {
		switch ($type) {
			"powershell" {
				$result = $vm.runScriptAsync($script, "Powershell")
				writeStdout($result)
			}
			"bat" {
				$result = $vm.runScript($script, "bat")
				writeStdout($result)
			}
			"interactive" {
				$tempFileName = $serverAddress + "_" + "$vmName" + ".txt"
				$script | set-content "..\www\upload\$tempFileName"
				$vm.copyFileToVm("..\www\upload\$tempFileName", "c:\temp\")
				$cmd = "
					move-item c:\temp\$tempFileName c:\temp\script.bat -force
					#schtasks /delete /f /tn runScript | out-null
					remove-item c:\temp\output*.txt -force -ea silentlycontinue
					`$date = get-date '2014/12/31' -format (Get-ItemProperty -path 'HKCU:\Control Panel\International').sshortdate
					schtasks /create /f /it /tn runScript /ru '$guestUser' /rp '$guestPassword' /rl HIGHEST /sc once /sd `$date /st 00:00:00 /tr 'c:\temp\script.bat' 
					schtasks /run /tn runScript | out-null
				"
				$vm.runScript($cmd, "Powershell")
				writeCustomizedMsg("Success - trigger interactive command in VM")
			}
		}
		[Environment]::exit("0")
	} else {
		$ip = $vm.getIPv4()
		$vm.enablePsRemote()
	}
}
$remoteWin = newRemoteWin $ip $guestUser $guestPassword
if ($type -eq "Powershell") {
	$result = $remoteWin.executePsTxtRemote($script, "run powershell script in VM")
} elseif ($type -eq "interactive"){
	$script | set-content "..\www\upload\$ip.txt"
	$remoteWin.sendFile("..\www\upload\$ip.txt", "c:\temp\script.ps1")
	$cmd = "
		`$date = get-date '2014/12/31' -format (Get-ItemProperty -path 'HKCU:\Control Panel\International').sshortdate
		schtasks /create /f /it /tn runScript /ru '$guestUser' /rp '$guestPassword' /rl HIGHEST /sc once /sd `$date /st 00:00:00 /tr 'powershell -file c:\temp\script.ps1 > c:\temp\output.txt' | out-null
		schtasks /run /tn runScript | out-null
	"
	$result = $remoteWin.executePsTxtRemote($cmd, "trigger interactive command in VM")
	$remoteWin.waitForTaskComplete("runScript", 600)
	$cmd = "
		get-content c:\temp\output.txt
	"
	$result = $remoteWin.executePsTxtRemote($cmd, "get script output")
	# writeCustomizedMsg $result
} else {
	$script | set-content "..\www\upload\$ip.txt"
	$remoteWin.sendFile("..\www\upload\$ip.txt", "c:\temp\script.bat")
	$script = "Invoke-WmiMethod -path win32_process -name create -argumentlist 'c:\temp\script.bat'"
	$result = $remoteWin.executePsTxtRemote($script, "trigger batch script in VM")
}

writeStdout($result)