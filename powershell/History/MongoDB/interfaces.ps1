<#
	.SYNOPSIS
    History (MongoDB)

	.DESCRIPTION
    Search execution history
	
	.NOTES
		AUTHOR: Jian Liu
		EMAIL: whirls9@hotmail.com
#>

Param (
	[parameter(
		HelpMessage="User name"
	)]
	[string]
		$user,	
		
	[parameter(
		HelpMessage="User IP address"
	)]
	[string]
		$userAddr,

	[parameter(
		HelpMessage="Script path"
	)]
	[string]
		$scriptPath,
    
  [parameter(
		HelpMessage="Method"
	)]
	[string]
		$method,
		
	[parameter(
		HelpMessage="Time in form of 'yyyy-mm-dd hh:mm:ss'. If defined, only records later than this time are selected"
	)]
	[string]
		$behindTime,
		
	[parameter(
		HelpMessage="Time in form of 'yyyy-mm-dd hh:mm:ss'. If defined, only records earlier than this time are selected"
	)]
	[string]
		$beforeTime,
		
	[parameter(
		HelpMessage="Return code"
	)]
	[string]
		$resultCode
)

foreach ($paramKey in $psboundparameters.keys) {
	$oldValue = $psboundparameters.item($paramKey)
	$newValue = [system.web.httputility]::urldecode("$oldValue")
	set-variable -name $paramKey -value $newValue
}

. .\utils.ps1

import-module MDBC
connect-mdbc . webcmd history

$records = get-mdbcdata
try {
	if ($behindTime) {
		$records = $records | ?{[datetime]$_.time -ge [datetime]$behindTime}
	}
	if ($beforeTime) {
		$records = $records | ?{[datetime]$_.time -le [datetime]$beforeTime}
	}
} catch {
	addToResult "Fail - parse time string"
	endError
}
if ($resultCode) {
	$records = $records | ?{$_.returncode -match "$resultCode"}
}
if ($scriptPath) {
	$records = $records | ?{$_.script -match "$scriptPath"}
}
if ($method) {
	$records = $records | ?{$_.method -match "$method"}
}
if ($userAddr) {
	$records = $records | ?{$_.useraddr -match "$userAddr"}
}
if ($user) {
	$records = $records | ?{$_.user -match "$user"}
}

if ($records) {
  addToResult "Success - find execution history"
  
  $total = ($records | measure-object).count
  $i = 0
  $history = @()
  
  $records | select -first 50000 | % {
    $number = $total - $i
    $i++
    $url = '/exec.php?hisId=' + $_._id
    $history += @{
      number=$number
      time=$_.time
      address=$_.useraddr
      user=$_.user
      result=$_.returncode
      script=$_.script
      method=$_.method
      log="<a target='blank' href='$url'>$($_._id)</a>"
    }
  }
  addToResult $history "dataset"
} else {
  addToResult "Fail - find execution history"
}
writeResult