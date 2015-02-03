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
        ADSI actions

	.DESCRIPTION
        This command handles ADSI actions.
		
	.FUNCTIONALITY
		AD
	
	.NOTES
		AUTHOR: Jerry Liu
		EMAIL: liuj@vmware.com
#>

Param (
	[parameter(
		Mandatory=$true,
		HelpMessage="IP or FQDN of the remote Windows machine"
	)]
	[string]
		$serverAddress,

	[parameter(
		HelpMessage="Port number, default is 389"
	)]
	[string]
		$port="389",
	
	[parameter(
		Mandatory=$true,
		HelpMessage="User name to connect to the remote Windows machine, in form of 'domain\username'"
	)]
	[string]
		$serverUser,
		
	[parameter(
		HelpMessage="Password of the user"
	)]
	[string]
		$serverPassword=$env:defaultPassword,
		
	[parameter(
		Mandatory=$true,
		HelpMessage="Distinguished name"
	)]
	[string]
		$dn,
	
	[parameter(
		HelpMessage="Filter"
	)]
	[string]	
		$filter,
		
	[parameter(
		Mandatory=$true,
		HelpMessage="Property name or 'name=value' pairs. Each definition per line. 
			If value contains multiple items, separate them by comma."
	)]
	[string]	
		$property,
	
	[parameter(
		HelpMessage="Action, default is get"
	)]
	[ValidateSet(
		"get",
		"clear",
		"update",
		"append",
		"delete"
	)]
	[string]
		$action="get"
)

foreach ($paramKey in $psboundparameters.keys) {
	$oldValue = $psboundparameters.item($paramKey)
	$newValue = [system.web.httputility]::urldecode("$oldValue")
	set-variable -name $paramKey -value $newValue
}

. .\objects.ps1

function newAdsiServer { 
	Param($address, $port, $user, $password, $dn, $filter)
	
	$root = New-Object DirectoryServices.DirectoryEntry("LDAP://$address`:$port/$dn", $user, $password)
	if ($filter) {
		$searcher = new-object System.DirectoryServices.DirectorySearcher($root)
		$searcher.filter = $filter
		$root = New-Object DirectoryServices.DirectoryEntry($searcher.findall()[0].path, $user, $password)
	}

	$adsiServer = New-Object PSObject -Property @{
		root = $root
		user = $user
		password = $password
	}
	
	$adsiServer | add-member -MemberType ScriptMethod -value {
        param($name)
		$value = $this.root.get($name)
		if ($value) {
			writeCustomizedMsg "Success - get ADSI property"
			write-host "<property><name>$name</name><value>$value</value></property>"
			return $value
		}
	} -name getProperty
	
	$adsiServer | add-member -MemberType ScriptMethod -value {
        param($name)
		$this.root.putex(1, $name, 0)
		$this.root.setinfo()
	} -name clearProperty
	
	$adsiServer | add-member -MemberType ScriptMethod -value {
        param($name, $value)
		$valueList = @($value.split(',').trim())
		$this.root.putex(2, $name, $valueList)
		$this.root.setinfo()
	} -name updateProperty
	
	$adsiServer | add-member -MemberType ScriptMethod -value {
        param($name, $value)
		$valueList = @($value.split(',').trim())
		$this.root.putex(3, $name, $valueList)
		$this.root.setinfo()
	} -name appendProperty
	
	$adsiServer | add-member -MemberType ScriptMethod -value {
        param($name)
		$this.root.putex(4, $name, 0)
		$this.root.setinfo()
	} -name deleteProperty
	
	return $adsiServer
}

$adsi = newAdsiServer $serverAddress $port $serverUser $serverPassword $dn $filter
$propList = $property.split("`n") | %{$_.trim()}
foreach ($prop in $propList) {
	$propName = $prop.split('=',2)[0]
	$propValue = $prop.split('=',2)[1]
	switch ($action) {
		"get" { 
			try {
				$adsi.getProperty($propName)
			} catch {
				writeCustomizedMsg "Fail - get ADSI property $propName"
				writeStderr
			}
		}
		"clear" {
			try {
				$adsi.clearProperty($propName)
				writeCustomizedMsg "Success - clear ADSI property $propName"
			} catch {
				writeCustomizedMsg "Fail - clear ADSI property $propName"
				writeStderr
			}
		}
		"update" {
			try {
				$adsi.updateProperty($propName, $propValue)
				writeCustomizedMsg "Success - update ADSI property $propname to $propvalue"
			} catch {
				writeCustomizedMsg "Fail - update ADSI property $propname to $propvalue"
				writeStderr
			}
		}
		"append" {
			try {
				$adsi.appendProperty($propName, $propValue)
				writeCustomizedMsg "Success - append $propvalue to ADSI property $propname"
			} catch {
				writeCustomizedMsg "Fail - append $propvalue to ADSI property $propname"
				writeStderr
			}
		}
		"delete" {
			try {
				$adsi.deleteProperty($propName)
				writeCustomizedMsg "Success - delete ADSI property $propName"
			} catch {
				writeCustomizedMsg "Fail - delete ADSI property $propName"
				writeStderr
			}
		}
		default {
			writeCustomizedMsg "Fail - unknown ADSI action $action"
		}
	}
}