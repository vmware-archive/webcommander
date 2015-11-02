<#
	.SYNOPSIS
    ADSI

	.DESCRIPTION
    This command handles ADSI actions
		
	.FUNCTIONALITY
		AD
	
	.NOTES
		AUTHOR: Jian Liu
		EMAIL: whirls9@hotmail.com
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

. .\utils.ps1
. .\adsi\object.ps1

$adsi = newAdsiServer $serverAddress $port $serverUser $serverPassword $dn $filter
$propList = $property.split("`n") | %{$_.trim()}
foreach ($prop in $propList) {
	$propName = $prop.split('=',2)[0]
	$propValue = $prop.split('=',2)[1]
	switch ($action) {
		"get" { 
      $adsi.getProperty($propName)
		}
		"clear" {
      $adsi.clearProperty($propName)
		}
		"update" {
      $adsi.updateProperty($propName, $propValue)
		}
		"append" {
      $adsi.appendProperty($propName, $propValue)
		}
		"delete" {
      $adsi.deleteProperty($propName)
		}
		default {
			addToResult "Fail - unknown ADSI action $action"
		}
	}
}
writeResult