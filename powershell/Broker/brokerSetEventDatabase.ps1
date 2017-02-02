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
        Set event database

	.DESCRIPTION
        This command sets event database on a broker.
		
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
		HelpMessage="Name of broker VM or IP / FQDN of broker machine"
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
		HelpMessage="IP / FQDN of database server"
	)]
	[string]
		$dbAddress, 
	
	[parameter(
		HelpMessage="Database server type, default is SQLSERVER"
	)]
	[ValidateSet(
		"SQLSERVER",
		"ORACLE"
	)]
		$dbType="SQLSERVER",
	
	[parameter(
		HelpMessage="Port, default is 1433"
	)]
	[string]
		$dbPort="1433",
	
	[parameter(
		Mandatory=$true,
		HelpMessage="Database name"
	)]
	[string]
		$dbName,
	
	[parameter(
		HelpMessage="Database user name, default is administrator"
	)]
	[string]
		$dbUser="administrator",
	
	[parameter(
		Mandatory=$true,
		HelpMessage="Password of dbUser"
	)]
	[string]
		$dbPassword=$env:defaultPassword,
	
	[parameter(
		Mandatory=$true,
		HelpMessage="Table prefix"
	)]
	[string]
		$tablePrefix
)

foreach ($paramKey in $psboundparameters.keys) {
	$oldValue = $psboundparameters.item($paramKey)
	$newValue = [System.Net.WebUtility]::urldecode("$oldValue")
	set-variable -name $paramKey -value $newValue
}

. .\objects.ps1

$setEventDb = {
	Param (
		$dbAddress, 
		$dbType,
		$dbPort,
		$dbName,
		$dbUser,
		$dbPassword,
		$tablePrefix
	)
	function Invoke-ModifyEventDatabase() {
	   param( [ADSI] $db = $(throw "Event database entry required"),
			  [String] $hostname = $(Read-Host -prompt "Hostname"),
			  [String] $port = $(Read-Host -prompt "Port"),
			  [String] $dbname = $(Read-Host -prompt "DB Name"),
			  [String] $user = $(Read-Host -prompt "User"),
			  [String] $password = $(Read-Host -prompt "Password"),
			  [String] $tableprefix = "manualeventdb",
			  [String] $servertype = "SQLSERVER")
	   $db.put("description", "Manually modified entry at " + (get-date))
	   $db.put("pae-databasepassword", $password)
	   $db.put("pae-DatabasePortNumber", $port)
	   $db.put("pae-DatabaseServerType", $servertype)
	   $db.put("pae-DatabaseUsername", $user)
	   $db.put("pae-DatabaseName", $dbname)
	   $db.put("pae-DatabaseTablePrefix", $tableprefix)
	   $db.put("pae-DatabaseHostName", $hostname)
	   $db.setinfo()
	   return $db
	}
	function Get-EventDatabase() {
		$dbou = [ADSI]"LDAP://localhost:389/OU=Database,OU=Properties,DC=vdi,DC=vmware,DC=int"
		$searcher = new-object System.DirectoryServices.DirectorySearcher($dbou)
		$searcher.filter="(objectclass=pae-EventDatabase)"
		$res = $searcher.findall()
		if ($res.count -eq 1) {
			return [ADSI] ($res[0].path)
		} else {
			return $null
		}
	}
	function New-EventDatabase() {
	   param( [String] $hostname = $(Read-Host -prompt "Hostname"),
			  [String] $port = $(Read-Host -prompt "Port"),
			  [String] $dbname = $(Read-Host -prompt "DB Name"),
			  [String] $user = $(Read-Host -prompt "User"),
			  [String] $password = $(Read-Host -prompt "Password"),
			  [String] $tableprefix = "manualeventdb",
			  [String] $servertype = "SQLSERVER")

	   $db = (Get-EventDatabase)
	   if ($db -ne $null) {
		  throw "The event database already exists"
	   }
	   $dbou = [ADSI]"LDAP://localhost:389/OU=Database,OU=Properties,DC=vdi,DC=vmware,DC=int"
	   $guid = [GUID]::NewGuid()
	   $db = $dbou.Create("pae-EventDatabase", "cn=" + $guid)
	   Invoke-ModifyEventDatabase $db $hostname $port $dbname $user $password $tableprefix $servertype
	}
	function Set-EventDatabase() {
	   param( [String] $hostname = $(Read-Host -prompt "Hostname"),
			  [String] $port = $(Read-Host -prompt "Port"),
			  [String] $dbname = $(Read-Host -prompt "DB Name"),
			  [String] $user = $(Read-Host -prompt "User"),
			  [String] $password = $(Read-Host -prompt "Password"),
			  [String] $tableprefix = "manualeventdb",
			  [String] $servertype = "SQLSERVER")

	   $db = (Get-EventDatabase)
	   if ($db -eq $null) {
		  throw "The event database entry does not already exist"
	   }
	   Invoke-ModifyEventDatabase $db $hostname $port $dbname $user $password $tableprefix $servertype
	}
	$db = (Get-EventDatabase)
	if ($db -eq $null) {
		New-EventDatabase $dbAddress $dbPort $dbName $dbUser $dbPassword $tablePrefix $dbType
	} else {
		Invoke-ModifyEventDatabase $db $dbAddress $dbPort $dbName $dbUser $dbPassword $tablePrefix $dbType
	}
}
if (verifyIp($vmName)) {
	$ip = $vmName
} else {
	$server = newServer $serverAddress $serverUser $serverPassword
	$vm = newVmWin $server $vmName $guestUser $guestPassword
	$vm.waitfortools()
	$ip = $vm.getIPv4()
	$vm.enablePsRemote()
}
$remoteWinBroker = newRemoteWinBroker $ip $guestUser $guestPassword
$remoteWinBroker.initialize()
try {
	invoke-command -ScriptBlock $setEventDb -session $remoteWinBroker.session -EA stop -argumentlist $dbAddress, $dbType, $dbPort, $dbName, $dbUser, $dbPassword, $tablePrefix
} catch {
	writeCustomizedMsg "Fail - set event database"
	writeStderr
	[Environment]::exit("0")
}
writeCustomizedMsg "Success - set event database"