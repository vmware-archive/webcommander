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
        Run workflow as command

	.DESCRIPTION
        This command runs a workflow as a command.
		This command could also be embedded in a workflow.
	
	.FUNCTIONALITY
		Workflow
		
	.NOTES
		AUTHOR: Jerry Liu
		EMAIL: liuj@vmware.com
#>

Param (
	[parameter(
		HelpMessage="Type of the workflow. Default is 'serial'"
	)]
	[validateSet(
		"serial",
		"parallel"
	)]
	[string]
		$type="serial",	
		
	[parameter(
		HelpMessage="Action upon error. Default is 'stop'"
	)]
	[validateSet(
		"stop",
		"continue"
	)]
	[string]
		$actionOnError="stop",

	[parameter(
		Mandatory=$true,
		HelpMessage="Workflow in form of JSON"
	)]
	[string]
		$workflow
)

foreach ($paramKey in $psboundparameters.keys) {
	$oldValue = $psboundparameters.item($paramKey)
	$newValue = [system.web.httputility]::urldecode("$oldValue")
	set-variable -name $paramKey -value $newValue
}

. .\objects.ps1

function replaceVar {
	param ($varValue, $definedVar)
	$newValue = $varValue
	if ($definedVar) {
		foreach ($dv in $definedVar) {
			if ($dv.value.gettype().name -eq "string") {
				$newValue = $newValue.replace($dv.name, $dv.value)
			}
		}
		$regex = [regex]"(\['[(\w)\-]*'\])+"
		$squareText = $regex.matches($newValue).value
		foreach ($s in $squareText) {
			$k = $s.replace('][','.').replace("['",'$').trim(']').replace("JSON'",'JSON')
			$k = invoke-expression $k
			if ($k) {
				$newValue = $newValue.replace($s,$k)
			}
		}
	}
	return $newValue
}

function replaceHash {
	param ($hashTable, $definedVar)
	$newHash = @{}
	foreach ($key in $hashTable.keys) {
		$keyVar = get-variable -scope global -name $key -ea silentlycontinue
		if ($hashTable.$key) {
			$value = replaceVar $hashTable.$key $definedVar
		} elseif ($keyVar) {
			$value = $keyVar.value
		} else {
			$value = ""
		}
		$newHash.add($key,$value)
	}
	return $newHash
}

try {
	$json = $workflow | convertFrom-Json
} catch {
	writeCustomizedMsg "Fail - read workflow JSON"
	writeStderr
	[Environment]::exit("0")
}
$url = "http://127.0.0.1/webcmd.php"
$existVar = get-variable -scope global
$paramHashList = @()
foreach ($cmd in $json) {
	$paramHash = @{}
	$key = $cmd | get-member -memberType NoteProperty | select name
	foreach ($k in $key) {
		$value = $cmd.($k.name)
		$paramHash.add($k.name,$value)
	}
	$paramHashList += $paramHash
}
$result = "Success"
$i = 1

foreach ($hash in $paramHashList) {
	writeSeparator
	writeCustomizedMsg ("Info - start command $i")
	$definedVar = get-variable -scope global -exclude $existVar.name
	if ($hash.command -eq "sleep") {
		$hash = replaceHash $hash $definedVar
		$second = [int]$hash.second
		if ($second -lt 1){$second = 1}
		elseif ($second -gt 3600) {$second = 3600}
		start-sleep $second
		writeCustomizedMsg ("Info - wait $second seconds")
	} elseif ($hash.command -eq "defineVariable") {
		$varList = $hash.variableList.split("`n") | %{$_.trim()}
		foreach ($var in $varList) {
			$varName = $var.split('=',2)[0]
			$varValue = replaceVar $var.split('=',2)[1] $definedVar
			Set-Variable -Name $varName -Value $varValue -Scope global -force
		}
		writeCustomizedMsg ("Info - define global variables")
	} else {
		$hash = replaceHash $hash $definedVar
		if ($type -eq "parallel") {
			start-job -ScriptBlock {
				invoke-webRequest -timeoutsec 86400 -uri $args[0] -body $args[1]
			} -argumentList $url,$hash -name "command $i"
		} else {
			[xml]$s = Invoke-WebRequest -timeoutsec 86400 -uri $url -body $hash
			if ($s.webcommander.returnCode -ne '4488') { 
				$cmdResult = "Fail"
			} else {
				$cmdResult = "Success"
				if ($hash.variableList) {
					$varList = $hash.variableList.split("`n") | %{$_.trim()}
					foreach ($var in $varList) {
						$varName = $var.split('=',2)[0]
						if ($varName -match "json`$") {
							$varValue = $s.selectNodes($var.split('=',2)[1])."#cdata-section" | convertfrom-json
						} else {
							$varValue = $s.selectNodes($var.split('=',2)[1])."#text"
						}
						Set-Variable -Name $varName -Value $varValue -Scope global
					}
				}
			}
			writeCustomizedMsg ("$cmdResult - execute command $i")
			$s.webcommander.result.innerxml
		}
	}
	writeCustomizedMsg ("Info - end command $i")
	if (($cmdResult -eq "Fail") -and ($actionOnError -eq "stop")) {
		$result = "Fail"
		break
	}
	$i++
}

if ($type -eq "parallel") {
	writeCustomizedMsg ("Info - wait parallel commands execution")
	get-job | wait-job
	foreach ($job in (get-job)) {
		writeSeparator
		[xml]$s = (receive-job $job).content
		if ($s.webcommander.returnCode -ne '4488') {
			$result = "Fail"
			$cmdResult = "Fail"
		} else {
			$cmdResult = "Success"
		}
		writeCustomizedMsg ("$cmdResult - execute $($job.name)")
		$s.webcommander.result.innerxml
	}
}
writeSeparator
writeCustomizedMsg ("$result - run workflow $name in $type")