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
$records = gci $historyPath\*.xml -recurse | select fullname, directory, creationTime | sort creationTime -desc
try {
	if ($behindTime) {
		$records = $records | ?{$_.creationTime -ge $behindTime}
	}
	if ($beforeTime) {
		$records = $records | ?{$_.creationTime -le $beforeTime}
	}
} catch {
	writeCustomizedMsg "Fail - parse time string"
	writeStderr
	[Environment]::exit("0")
}
if ($resultCode) {
	$records = $records | ?{$_.directory.basename -match "$resultCode"}
}
if ($cmdName) {
	$records = $records | ?{$_.directory.parent.basename -match "$cmdName"}
}
if ($userAddr) {
	$records = $records | ?{$_.directory.parent.parent.basename -match "$userAddr"}
}
if ($user) {
	$records = $records | ?{$_.directory.parent.parent.parent.basename -match "$user"}
}
if ($records) {
	writeCustomizedMsg "Success - find execution history"
	"<history>"
	$i = 1
	$records | % {
		$path = $_.fullname.replace("$historyPath\","").split("\")
		"<record><number>$i</number>"
		"<time>" + $_.creationTime + "</time>"
		"<user>" + $path[0] + "</user>"
		"<useraddr>" + $path[1] + "</useraddr>"
		"<cmdname>" + $path[2] + "</cmdname>"
		"<resultcode>" + $path[3] + "</resultcode>"
		"<filename>" + $path[4] + "</filename>"
		"</record>"
		$i++
	}
	"</history>"
} else {
	writeCustomizedMsg "Fail - find execution history"
}