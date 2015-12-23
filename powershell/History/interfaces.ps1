<#
Copyright (c) 2012-2015 VMware, Inc.

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
    History

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

. .\utils.ps1

$psPath = split-path -parent (pwd).path
$historyPath = "$psPath\www\history"
$records = [io.Directory]::EnumerateFiles($historyPath,"*.json","AllDirectories") | `
  Sort-Object {$_.SubString($_.IndexOf('output-'))} -desc | `
  %{$_.replace("$historypath\","")}
[datetime]$origin = '1970-01-01 00:00:00'
try {
	if ($behindTime) {
		$records = $records | ?{$_.split("output-")[-1].replace(".json","") -ge ([datetime]$behindTime - $origin).totalseconds}
	}
	if ($beforeTime) {
		$records = $records | ?{$_.split("output-")[-1].replace(".json","") -le ([datetime]$beforeTime - $origin).totalseconds}
	}
} catch {
	addToResult "Fail - parse time string"
	endError
}
if ($resultCode) {
	$records = $records | ?{$_.split("\")[-2] -match "$resultCode"}
}
if ($scriptPath) {
	$records = $records | ?{$_ -match "$scriptPath"}
}
if ($userAddr) {
	$records = $records | ?{$_.split("\")[1] -match "$userAddr"}
}
if ($user) {
	$records = $records | ?{$_.split("\")[0] -match "$user"}
}
if ($records) {
	addToResult "Success - find execution history"
	
	$stringBuilder = New-Object System.Text.StringBuilder
  
  $total = ($records | measure-object).count
  $i = 0
  
  $history=@()
	$records | select -first 50000 | % {
    $script = [regex]::match($_, '(?<=\\(\d{1,3}.){3}\d{1,3}\\).+(?=\\\d{4}\\)').value
		$path = $_.replace("$historyPath\","").split("\")
		$seconds = ($_ -split "output-")[-1].replace(".json","")
		$time = $origin.AddSeconds($seconds).tostring()
    $url = '/index.html?/history/' + ($path -join "/")
    $number = $total - $i
    $i++ 
    $history += @{
      number=$number
      time=$time
      user=$path[0]
      address=$path[1]
      script=$script
      result=$path[-2]
      log="<a target='blank' href='$url'>$($path[-1])</a>"
    }
	}
  addToResult $history "dataset"
} else {
	addToResult "Fail - find execution history"
}
writeResult