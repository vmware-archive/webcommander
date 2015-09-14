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
    Show command history

	.DESCRIPTION
    This command displays webCommander commands' history.
		The result could be filtered by conditions.
    Owing to the limit of client side datatable, the maximum mumber of 
    records to display is 50000.
	
	.Functionality
		History
	
	.NOTES
		AUTHOR: Jerry Liu
		EMAIL: liuj@vmware.com
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
		HelpMessage="Command name"
	)]
	[string]
		$cmdName,
		
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

. .\objects.ps1

$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition 
$historyPath = $scriptPath.replace("powershell", "www\history")
$records = [io.Directory]::EnumerateFiles($historyPath,"*.xml","AllDirectories") | Sort-Object {$_.SubString($_.IndexOf('output-'))} -desc
[datetime]$origin = '1970-01-01 00:00:00'
try {
	if ($behindTime) {
		$records = $records | ?{$_.split("output-")[-1].replace(".xml","") -ge ([datetime]$behindTime - $origin).totalseconds}
	}
	if ($beforeTime) {
		$records = $records | ?{$_.split("output-")[-1].replace(".xml","") -le ([datetime]$beforeTime - $origin).totalseconds}
	}
} catch {
	writeCustomizedMsg "Fail - parse time string"
	writeStderr
	[Environment]::exit("0")
}
if ($resultCode) {
	$records = $records | ?{$_.split("\")[-2] -match "$resultCode"}
}
if ($cmdName) {
	$records = $records | ?{$_.split("\")[-3] -match "$cmdName"}
}
if ($userAddr) {
	$records = $records | ?{$_.split("\")[-4] -match "$userAddr"}
}
if ($user) {
	$records = $records | ?{$_.split("\")[-5] -match "$user"}
}
if ($records) {
	writeCustomizedMsg "Success - find execution history"
	
	$stringBuilder = New-Object System.Text.StringBuilder
	$null = $stringBuilder.append("<history><![CDATA[")
  
  $total = ($records | measure-object).count
  $i = 0

	$records | select -first 50000 | % {
		$path = $_.replace("$historyPath\","").split("\")
		$seconds = $_.split("output-")[-1].replace(".xml","")
		$time = $origin.AddSeconds($seconds)
    $url = '/history/' + ($path -join "/")
    $number = $total - $i
    $i++
    $record = "[ ""$number"", ""$time"", ""$($path[0])"", ""$($path[1])"", ""$($path[2])"", ""$($path[3])"", ""<a target='blank' href='$url'>$($path[4])</a>"" ]," 
		$null = $stringBuilder.Append($record)
	}
  $null = $stringBuilder.remove($stringBuilder.length - 1 , 1)
	$null = $stringBuilder.append("]]></history>")
	write-output $stringBuilder.toString()
} else {
	writeCustomizedMsg "Fail - find execution history"
}