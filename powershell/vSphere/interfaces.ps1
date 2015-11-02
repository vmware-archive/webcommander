<#
	.SYNOPSIS
		vSphere 

	.DESCRIPTION
		ESXi / VC functions
		
	.NOTES
		AUTHOR: Jian Liu
		EMAIL: whirls9@hotmail.com
#>

Param (
	[parameter(
		Mandatory=$true,
		HelpMessage="IP or FQDN of ESX or VC server. Support multiple values seperated by comma."
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
    parameterSetName="listPortGroup",
    Mandatory=$true,
		HelpMessage="Port group name"
	)]
	[string]
		$portGroupName,
    
  [parameter(
    parameterSetName="listDatastore",
    Mandatory=$true,
		HelpMessage="Datastore name"
	)]
	[string]
		$datastoreName,
    
  [parameter(
    parameterSetName="listResourcePool",
    Mandatory=$true,
		HelpMessage="Resource pool name"
	)]
	[string]
		$resourcePoolName
)

foreach ($paramKey in $psboundparameters.keys) {
	$oldValue = $psboundparameters.item($paramKey)
	$newValue = [system.web.httputility]::urldecode("$oldValue")
	set-variable -name $paramKey -value $newValue
}

. .\utils.ps1
. .\vsphere\object.ps1

$serverList = $serverAddress.split(",") | %{$_.trim()} | newServer -user $serverUser -password $serverPassword
switch ($pscmdlet.parameterSetName) {
  "listPortGroup" { 
    $serverList | % { $_.listPortGroup($portGroupName) } 
  }
  "listDatastore" {
    $serverList | % { $_.listDatastore($datastoreName) } 
  }
  "listResourcePool" {
    $serverList | % { $_.listResourcePool($resourcePoolName) }
  }
}
writeResult