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
		Install dotNet 4.5 

	.DESCRIPTION
		This command downloads and installs dotNet Framework 4.5.2.
		This command could execute on multiple machines.
		
	.FUNCTIONALITY
		Install
		
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
		$guestPassword=$env:defaultPassword
)

foreach ($paramKey in $psboundparameters.keys) {
	$oldValue = $psboundparameters.item($paramKey)
	$newValue = [System.Net.WebUtility]::urldecode("$oldValue")
	set-variable -name $paramKey -value $newValue
}

. .\objects.ps1

function installDotNet {
	param($ip, $guestUser, $guestPassword)
	$remoteWin = newRemoteWin $ip $guestUser $guestPassword
	#new-psdrive -name Y -PSProvider filesystem -Root "\\$ip\c`$\temp" -cred $remoteWin.cred
	#copy-item "..\postinstall\dotNet\NDP452-KB2901907-x86-x64-AllOS-ENU.exe" "Y:\"
	
	$url = 'http://download.microsoft.com/download/E/2/1/E21644B5-2DF2-47C2-91BD-63C560427900/NDP452-KB2901907-x86-x64-AllOS-ENU.exe'
	$bin = ($url.split("/"))[-1]
	$cmd = "
		`$wc = new-object system.net.webclient;
		`$wc.downloadfile('$url', 'c:\temp\$bin');
		get-item 'c:\temp\$bin' -ea Stop
	"
	$remoteWin.executePsTxtRemote($cmd, "download dotNet 4.5.2.")
	
	$cmd = "
		`$installprocess = [System.Diagnostics.Process]::Start('c:\temp\$bin', ' /passive /norestart')
		`$installprocess.WaitForExit()
		If ((0,3010) -notcontains `$installprocess.ExitCode) {    
			throw ('Fail to install dotNet 4.5.2. Exit code:' + `$installprocess.ExitCode)
		}
	"
	$remoteWin.executePsTxtRemote($cmd, "install dotNet 4.5.2", 2400)
	$remoteWin.restart()
}

$ipList = getVmIpList $vmName $serverAddress $serverUser $serverPassword
$ipList | % {
	installDotNet $_ $guestUser $guestPassword
}