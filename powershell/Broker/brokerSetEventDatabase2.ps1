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