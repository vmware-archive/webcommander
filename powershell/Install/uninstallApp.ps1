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
		Uninstall MSI applications 

	.DESCRIPTION
		This command uninstalls applications from Windows machines.
		This command could execute on multiple machines to uninstall
		multiple applications.
		Only support applications with MSI installers.
		
	.FUNCTIONALITY
		Broker_RDS
		
	.NOTES
		AUTHOR: Jerry Liu
		EMAIL: liuj@vmware.com
#>

Param (
	[parameter(
		HelpMessage="IP or FQDN of the ESX or VC server where target VM is located"
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
		HelpMessage="Name of target VM or IP / FQDN of target machine. Support multiple values seperated by comma. VM name and IP could be mixed."
	)]
	[string]
		$vmName, 
	
	[parameter(
		HelpMessage="User of target machine (default is administrator)"
	)]
	[string]	
		$guestUser="administrator", 
		
	[parameter(
		HelpMessage="Password of guestUser"
	)]
	[string]	
		$guestPassword=$env:defaultPassword,  
	
	[parameter(
		Mandatory=$true,
		HelpMessage="Name of application to uninstall. Support multiple values seperated by comma."
	)]
	[string]
		$appName
)

foreach ($paramKey in $psboundparameters.keys) {
	$oldValue = $psboundparameters.item($paramKey)
	$newValue = [system.web.httputility]::urldecode("$oldValue")
	set-variable -name $paramKey -value $newValue
}

. .\objects.ps1

function uninstallApp {
	param ($ip, $guestUser, $guestPassword, $appList)
	$remoteWin = newRemoteWin $ip $guestUser $guestPassword
	foreach ($appName in $appList) {
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
}		

$appList = $appName.split(",") | %{$_.trim()}
$ipList = getVmIpList $vmName $serverAddress $serverUser $serverPassword
$ipList | % {
	uninstallApp $_ $guestUser $guestPassword $appList
}