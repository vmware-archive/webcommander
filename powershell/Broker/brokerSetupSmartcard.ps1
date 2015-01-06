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
        Setup smartcard environment

	.DESCRIPTION
        This command setup and configure smartcard environment on brokers.
		This command could execute on multiple brokers.
		
	.FUNCTIONALITY
		Broker
	
	.NOTES
		AUTHOR: Jerry Liu
		EMAIL: liuj@vmware.com
#>

Param (
	[parameter(
		HelpMessage="IP or FQDN of the ESX or VC server where the broker VM is located"
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
		HelpMessage="Name of the VM or IP / FQDN of broker machine. Support multiple values seperated by comma. VM name and IP could be mixed."
	)]
	[string]
		$vmName, 
	
	[parameter(
		HelpMessage="User of broker (default is administrator)"
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
		HelpMessage="CA certificate"
	)]
	[string]	
		$certFile
)

foreach ($paramKey in $psboundparameters.keys) {
	$oldValue = $psboundparameters.item($paramKey)
	$newValue = [system.web.httputility]::urldecode("$oldValue")
	set-variable -name $paramKey -value $newValue
}

. .\objects.ps1

function setupSmartCard {
	param ($ip, $guestUser, $guestPassword, $certFile)
	$remoteWinBroker = newRemoteWinBroker $ip $guestUser $guestPassword
	$remoteWinBroker.sendFile("$certFile", "C:\temp\certnew.cer")
	$script = {
		remove-item c:\temp\trust.key -ea silentlyContinue
		& "C:\Program Files\VMware\VMware View\Server\jre\bin\keytool.exe" -import -alias alias -file C:\temp\certnew.cer -keystore c:\temp\trust.key -storepass 111111 -noprompt 2>null
		copy-item c:\temp\trust.key "C:\Program Files\VMware\VMware View\Server\sslgateway\conf\" 
		$content = @"
trustKeyfile=trust.key
trustStoretype=JKS
useCertAuth=true
"@
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
	writeStdout($result)
	writeCustomizedMsg "Success - setup smartcard"	
}	

$ipList = getVmIpList $vmName $serverAddress $serverUser $serverPassword
$ipList | % {
	setupSmartCard $_ $guestUser $guestPassword $certFile
}