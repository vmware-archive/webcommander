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
        Generate command definition

	.DESCRIPTION
        This command generates _def.xml.
		It parses all powershell scripts to get information from comment
		based help and parameter attributes.
#>

## Author: Jerry Liu, liuj@vmware.com

. .\objects.ps1

function createCmdDefXml {
	param ($cmd,$scriptPath)
	$xml = ""
	$help = get-help $cmd.definition -full
	$name = ($cmd.name -replace ".ps1","")
	if ($help.gettype().name -eq "PSCustomObject") {
		if ($help.functionality -match "noshow") {return}
		$xml += '<command name="' + $name + `
			'" synopsis="' + $help.synopsis + '"'
		if ($help.functionality -match "hidden") {
			$xml += ' hidden="1"'
		}		
		$xml += '>'
		
		if ($help.description) {
			$xml += '<description>' + $help.description.text + '</description>'
		}
		
		if ($help.functionality) {
			$xml += '<functionalities>'
			foreach ($fun in $help.functionality.split(",").trim()) {
				if ($fun -eq "hidden") {continue}
				$xml += '<functionality>' + $fun + '</functionality>'
			}
			$xml += '</functionalities>'
		}
	} else {
		$xml += '<command name="' + $name + '" synopsis="' + $name + '">'
		$folders = $cmd.definition.replace($scriptPath,"").split("\")
		if ($folders.count -gt 1) {
			$xml += '<functionalities>'
			for ($i=0;$i -lt $folders.count - 1; $i++) {
				$xml += '<functionality>' + $folders[$i] + '</functionality>'
			}
			$xml += '</functionalities>'
		}
	}
	$script = $cmd.definition.replace($scriptPath,"").replace(".ps1","")
	$xml += '<script>' + $script + '</script>'
	
	$commonParam = @("ErrorAction","WarningAction","Verbose","ErrorVariable",
		"Debug","WarningVariable","OutVariable","OutBuffer","PipelineVariable")
	if ($cmd.parameters.keys.count) {
		$xml += '<parameters>'
		foreach ($k in $cmd.parameters.keys) {
			$name = $cmd.parameters["$k"].name
			if ($name -in $commonParam){continue}
			$pAttr = $cmd.parameters["$k"].attributes | `
				?{$_.TypeId.name -match "ParameterAttribute"}
			$helpmsg = $pAttr.HelpMessage
			if ($help.gettype().name -eq "PSCustomObject") {
				$mandatory = [int]$pAttr.mandatory
			} else {
				$mandatory = 1
			}
			$vsAttr = $cmd.parameters["$k"].attributes | `
				?{$_.TypeId.name -match "ValidateSetAttribute"}
			$vv = $vsAttr.validvalues
			$xml += '<parameter name="' + $name + '" helpmessage="' + `
				$helpmsg + '" mandatory="' + $mandatory + '" '
			if ($name -match "password$") {
				$xml += 'type="password" />' 
			} elseif ($vv) {
				$xml += 'type="option"><options>'
				foreach ($v in $vv) {
					$xml += '<option value="' + $v + '">' + $v + '</option>'
				}
				$xml += '</options></parameter>'
			} elseif ($name -match "(script|property|url)$") {
				$xml += 'type="textarea" />'
			} elseif ($name -match "file$") {
				$xml += 'type="file" />'
			} else {
				$xml += '/>'
			}
		}
		$xml += '</parameters>'
	}
	$xml += '</command>'
	return $xml
}

$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
$commands = @()
gci $scriptPath\*.ps1 -recurse | % {
	$commands += get-command $_.fullname 
}
$xml = @'
<?xml version="1.0"?>
<webcommander xmlns:xi="http://www.w3.org/2003/XInclude">
'@
foreach ($cmd in $commands) {
	$xmlPath = $cmd.definition.replace(".ps1",".xml")
	if (test-path $xmlPath) {
		$xmlPath = $xmlPath.replace("$scriptPath\", "").replace("\","/")
		$xml += "<xi:include href=""$xmlPath"" xpointer=""xpointer(//command)"" parse=""xml"" />"
	} else {
		$xml += createCmdDefXml $cmd ($scriptPath + "\")
	}
}
$xml += '</webcommander>'

$timeSuffix = get-date -format "yyyy-MM-dd-hh-mm-ss"
copy "$scriptPath\_def.xml" "$scriptPath\_def-$timeSuffix.xml" -force
writeCustomizedMsg "Info - copy current definition XML to _def-$timeSuffix.xml"

try {
	$def = new-object XML
	$def = [XML]$xml
	# $sorted = $def.SelectNodes("//command") | sort {$_.functionalities.functionality, $_.synopsis}
	# $cmd = $def.selectsinglenode("webcommander")
	# $cmd.removeall()
	# $sorted | %{$cmd.appendchild($_)}
	$def.save("$scriptPath\_def.xml")
} catch {
	writeCustomizedMsg "Fail - generate command definition XML"
	writeStderr
	[Environment]::exit("0")	
}
writeCustomizedMsg "Success - generate command definition XML"