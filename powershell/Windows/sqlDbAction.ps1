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
	$dbServerName,
	$dbName,
	$action="create"
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
	$ip = $vm.getIPv4()
	$vm.enablePsRemote()
}

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