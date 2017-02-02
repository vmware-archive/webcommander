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
		Create / drop database 

	.DESCRIPTION
		This command creates or drops a database on SQL server.
		This command could execute against multiple SQL servers.
		
	.FUNCTIONALITY
		SQL_Server
		
	.NOTES
		AUTHOR: Jerry Liu
		EMAIL: liuj@vmware.com
#>

Param (
	[parameter(
		HelpMessage="IP or FQDN of the ESX or VC server where SQL server VM is located"
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
		HelpMessage="Name of SQL server VM or IP / FQDN of SQL server. Support multiple values seperated by comma. VM name and IP could be mixed."
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
		HelpMessage="SQL server name, such as 'MICROSO-N9U1D7A\SQLEXPRESS'"
	)]
	[string]
		$dbServerName,
	
	[parameter(
		Mandatory=$true,
		HelpMessage="Database name"
	)]
	[string]
		$dbName,
	
	[parameter(
		Mandatory=$true,
		HelpMessage="Action on database, create or drop"
	)]
	[ValidateSet(
		"create",
		"drop"
	)]
	[string]
		$action
)

foreach ($paramKey in $psboundparameters.keys) {
	$oldValue = $psboundparameters.item($paramKey)
	$newValue = [System.Net.WebUtility]::urldecode("$oldValue")
	set-variable -name $paramKey -value $newValue
}

. .\objects.ps1

function sqlAction {
	param($ip, $guestUser, $guestPassword, $dbServerName, $dbName, $action)
	$remoteWin = newRemoteWin $ip $guestUser $guestPassword
	if ($action -eq "drop") {
		$cmd = "
			[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
			`$srv = new-object ('Microsoft.SqlServer.Management.Smo.Server') '$dbServerName' 
			(`$srv.databases | ?{`$_.name -eq '$dbName'}).drop()
			#`$srv.ConnectionContext.LoginSecure=`$false;
			#`$srv.ConnectionContext.set_Login('$dbUser');
			#`$srv.ConnectionContext.set_Password('$dbPassword')
		"
		$remoteWin.executePsTxtRemote($cmd, "$action database $dbName on SQL server $dbServerName")
	} elseif ($action -eq "create") {
		$cmd = "
			[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
			`$srv = new-object Microsoft.SqlServer.Management.Smo.Server '$dbServerName' 
			`$db = new-object Microsoft.SqlServer.Management.Smo.Database (`$srv, '$dbName')
			`$db.Create()
		"
		$remoteWin.executePsTxtRemote($cmd, "$action database $dbName on SQL server $dbServerName")
	} else {
		writeCustomizedMsg "Fail - unknown database action"
	}
}

$ipList = getVmIpList $vmName $serverAddress $serverUser $serverPassword
$ipList | % {
	sqlAction $_ $guestUser $guestPassword $dbServerName $dbName $action
}