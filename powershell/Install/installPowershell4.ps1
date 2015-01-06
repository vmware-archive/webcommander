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
		Install Powershell 4.0 

	.DESCRIPTION
		This command downloads and installs Powershell 4.0.
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
	$newValue = [system.web.httputility]::urldecode("$oldValue")
	set-variable -name $paramKey -value $newValue
}

. .\objects.ps1

function installPowershell {
	param($ip, $guestUser, $guestPassword)
	$remoteWin = newRemoteWin $ip $guestUser $guestPassword

	$ver = $remoteWin.getOsVersion()
	$type = $remoteWin.getOsType()
	if ($ver -lt 6.1){
		writeCustomizedMsg "Fail - upgrade Powershell"
		writeCustomizedMsg "Warn - latest Powershell is not supportted on Windows $ver"
		return
	} elseif (($ver -gt 6.1) -and ($ver -lt 6.2)) {
		if ($type -eq "x86") {
			$url = 'http://download.microsoft.com/download/3/D/6/3D61D262-8549-4769-A660-230B67E15B25/Windows6.1-KB2819745-x86-MultiPkg.msu'
		} else {
			$url = 'http://download.microsoft.com/download/3/D/6/3D61D262-8549-4769-A660-230B67E15B25/Windows6.1-KB2819745-x64-MultiPkg.msu'
		}
	} elseif (($ver -gt 6.2) -and ($ver -lt 6.3)) {
		$url = 'http://download.microsoft.com/download/3/D/6/3D61D262-8549-4769-A660-230B67E15B25/Windows8-RT-KB2799888-x64.msu'
	} else {
		writeCustomizedMsg "Fail - upgrade Powershell"
		writeCustomizedMsg "Warn - no new Powershell is available for Windows $ver"
		return
	}
	$bin = ($url.split("/"))[-1]
	$cmd = "
		`$wc = new-object system.net.webclient;
		`$wc.downloadfile('$url', 'c:\temp\$bin');
		get-item 'c:\temp\$bin' -ea Stop
	"
	$remoteWin.executePsTxtRemote($cmd, "download Powershell 4.0.")
	$cmd = "
		`$installprocess = [System.Diagnostics.Process]::Start('c:\temp\$bin', ' /quiet /norestart')
		`$installprocess.WaitForExit()
		If ((0,3010) -notcontains `$installprocess.ExitCode) {    
			write-output ('Fail to install Powershell 4.0. Exit code:' + `$installprocess.ExitCode)
		}
	"
	#$remoteWin.executePsTxtRemote($cmd, "install Powershell 4.0", 2400)
	$result = $remoteWin.runInteractivePs1($cmd)
	if ($result -match "Fail"){
		writeCustomizedMsg "Fail - install Powershell 4.0"
		writeStdout $result
		return
	}
	writeCustomizedMsg "Success - install Powershell 4.0"
	$remoteWin.restart()
}

$ipList = getVmIpList $vmName $serverAddress $serverUser $serverPassword
$ipList | % {
	installPowershell $_ $guestUser $guestPassword
}