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
	$appName
)

foreach ($paramKey in $psboundparameters.keys) {
	$oldValue = $psboundparameters.item($paramKey)
	$newValue = [system.web.httputility]::urldecode("$oldValue")
	set-variable -name $paramKey -value $newValue
}

. .\objects.ps1

function uninstallApp {
	param ($ip, $guestUser, $guestPassword, $appName)
	$remoteWin = newRemoteWin $ip $guestUser $guestPassword
	if ($appName -match "VMwareVDMDS") {
		$cmd = "
			`$cmdPara = ' /q /force /i:VMwareVDMDS'
			`$cmd = 'c:\windows\adam\adamuninstall.exe'
			`$installprocess = [System.Diagnostics.Process]::Start(`$cmd, `$cmdPara)
			`$installprocess.WaitForExit()
		"
		$remoteWin.executePsTxtRemote($cmd, "remove AD LDS instance $appName")
	} else {
		$reg = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
		$cmd = "
			`$app = Get-WmiObject -Class Win32_Product | ? { 
				`$_.Name -match '$appName'
			}
			if (`$app) {
				`$app.Uninstall()
			} else {
				`$app = Get-ItemProperty '$reg\*' | ? {
					`$_.displayname -match '$appName'
				}
				if (`$app) {
					if (`$app.uninstallstring) {
						get-process | ?{'$appName' -match `$_.processName} | kill
						`$uninstaller = `$app.uninstallstring.replace('""', '').replace(' ', '` ')
						# `$installprocess = [System.Diagnostics.Process]::Start(`$uninstaller, ' /S')
						# `$installprocess.WaitForExit()
						Start-process `$uninstaller -wait -argumentlist ' /S' -ea Stop
					} else {
						throw '$appName does not provide an uninstall string'
					}			
				} else {
					throw 'Can not find $appName on the target machine'
				}
			}
		"
		$remoteWin.executePsTxtRemote($cmd, "uninstall application $appName")
	}
}		

$vmNameList = $vmName.split(",") | %{$_.trim()}	
foreach ($vmName in $vmNameList) {
	if (verifyIp($vmName)) {
		$ip = $vmName
		writeCustomizedMsg "Info - remote machine is $ip"
		uninstallApp $ip $guestUser $guestPassword $appName
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
			uninstallApp $ip $guestUser $guestPassword $appName
			writeSeperator
		}	
	}	
}