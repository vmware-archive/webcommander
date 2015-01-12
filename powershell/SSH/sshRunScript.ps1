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
		Run script remotely via SSH 

	.DESCRIPTION
		This command runs user defined script remotely over SSH.
		This command could run script on multiple SSH servers.
		If the remote scipt's exit code is not 0, it returns a failure.
		The remote script's output could also be checked for verification.
		
	.FUNCTIONALITY
		SSH
		
	.NOTES
		AUTHOR: Jerry Liu
		EMAIL: liuj@vmware.com
#>

Param (
	[parameter(
		Mandatory=$true,
		HelpMessage="IP or FQDN of SSH server. Support multiple values seperated by comma."
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
		HelpMessage="Script to run"
	)]
	[string]
		$script,
		
	[parameter(
		HelpMessage="Method to check if specific string could (or could not) be found in output. Default is 'like'."
	)]
	[ValidateSet(,
		"like",
		"notlike",
		"match",
		"notmatch"
	)]
	[string]
		$outputCheck="like",
		
	[parameter(
		HelpMessage="String pattern to find"
	)]
	[string]
		$pattern
)

foreach ($paramKey in $psboundparameters.keys) {
	$oldValue = $psboundparameters.item($paramKey)
	$newValue = [system.web.httputility]::urldecode("$oldValue")
	set-variable -name $paramKey -value $newValue
}

. .\objects.ps1

$serverList = @($serverAddress.split(",") | %{$_.trim()})
$serverList | % {
	$sshServer = newSshServer $_ $serverUser $serverPassword
	$sshServer.runCommand($script, $outputCheck, $pattern)
}