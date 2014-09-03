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

param (
	$name,
	$type="serial", 
	$errorAction="stop",
	$workflow,
	$emailTo='liuj@vmware.com'
)

foreach ($paramKey in $psboundparameters.keys) {
	$oldValue = $psboundparameters.item($paramKey)
	$newValue = [system.web.httputility]::urldecode("$oldValue")
	set-variable -name $paramKey -value $newValue
}

. .\objects.ps1

$smtpServer = "smtp.vmware.com"
$msg = new-object Net.Mail.MailMessage 
$smtp = new-object Net.Mail.SmtpClient($smtpServer) 
$msg.From = "webCommander@vmware.com" 
$msg.To.Add($emailTo) 
$msg.Subject  = "webCommander notification"
$msg.body = $type.toUpper() + " workflow $name result`n"

$json = $workflow | convertFrom-Json
$urlList = @()
foreach ($cmd in $json) {
	$queryString = ""
	$key = $cmd | get-member -memberType NoteProperty | select name
	foreach ($k in $key) {
		$value = $cmd.($k.name)
		$queryString += $k.name + "=" + $value + "&" 
	}
	$urlList += "http://10.136.240.188/webcmd.php?" + $queryString
}

$result = "Success"
$i = 1
if ($type -eq "parallel") {
	foreach ($url in $urlList) {
		start-job -scriptBlock {invoke-webRequest -timeoutsec 86400 -uri $args[0]} -argumentList $url -name "command $i"
		$i++
	}
	get-job | wait-job
	for ($j=1; $j -lt $i; $j++) {
		$cmdResult = get-job -name "command $j" | receive-job
		if ($cmdResult | select-string "<returnCode>4488</returnCode>") {
			writeCustomizedMsg ("Success - command $j")
			$msg.body += "`n===================`n"
			$msg.body += "Success - command $j"
			$msg.body += "`n===================`n"
		} else {
			writeCustomizedMsg ("Fail - command $j")
			$msg.body += "`n===================`n"
			$msg.body += "Fail - command $j"
			$msg.body += "`n===================`n"
			$result = "Fail"
		}
		$msg.body += $cmdResult
	}
} else {
	foreach($url in $urlList) {
		[xml]$s = Invoke-WebRequest -timeoutsec 86400 -uri $url
		if ($s.webcommander.returnCode -ne '4488') { 
			$cmdResult = "Fail"
		} else {
			$cmdResult = "Success"
		}
		writeCustomizedMsg ("$cmdResult - command $i")
		$msg.body += "`n===================`n"
		$msg.body += "$cmdResult - command $i"
		$msg.body += "`n===================`n"
		$msg.body += $s.innerXml
		if (($cmdResult -eq "Fail") -and ($errorAction -eq "stop")) {
			$result = "Fail"
			break
		} else {$i++}
	}
}
writeCustomizedMsg ("$result - run workflow $name in $type")
$smtp.Send($msg)