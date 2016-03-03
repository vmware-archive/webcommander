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
    Generate command definition

  .DESCRIPTION
    This command generates _def.json.
    It parses all powershell scripts to get information from comment
    based help and parameter attributes.

  .NOTES
    AUTHOR: Jian Liu
    EMAIL: whirls9@hotmail.com
#>

param(
  [switch]$forceUpdate
)

. .\utils.ps1

function getDev {
  param ($h)
  $email = $h.alertset.alert.text.split("`n") | ?{$_ -match "EMAIL: "}
  $dev = $email.split("EMAIL: ")[-1]
  return $dev
}

function newCommand {
  param ($cmd,$scriptPath)
  try {
    $help = get-help $cmd.definition -full -ea stop
  } catch {
    addToResult "Fail - get help of $($cmd.definition)"
    endError
  }
  
  addToResult "Success - get help of $($cmd.definition)"
  
  $functionalities = @()
  $parametersets = @()
  $parameters = @()
  if ($help.gettype().name -eq "PSCustomObject") {
    if ($help.functionality -match "noshow") {return}
    $synopsis = $help.synopsis
    if ($help.functionality -match "hidden") {
      $hidden = $true
    }
    $developer = getDev $help
    $description = $help.description.text
    if ($help.functionality) {
      foreach ($fun in $help.functionality.split(",").trim()) {
        if ($fun -eq "hidden") {continue}
        $functionalities += $fun
      }
    }
  } else {
    $folders = $cmd.definition.replace($scriptPath,"").split("\")
    if ($folders.count -gt 1) {
      for ($i=0;$i -lt $folders.count - 1; $i++) {
        $functionalities += $folders[$i]
      }
    }
  }
  $script = $cmd.definition.replace($scriptPath,"")
  
  $commonParam = @("ErrorAction","WarningAction","Verbose","ErrorVariable",
    "Debug","WarningVariable","OutVariable","OutBuffer","PipelineVariable",
    "InformationAction", "InformationVariable")
  if ($cmd.parametersets.count -gt 1){
    foreach ($p in $cmd.parametersets) {
      $parametersets += $p.name
    }
  }
  
  if ($cmd.parameters.keys.count) {
    foreach ($k in $cmd.parameters.keys) {
      $options = @()
      $isSwitch = $cmd.parameters["$k"].SwitchParameter
      $name = $cmd.parameters["$k"].name
      if ($name -in $commonParam){continue}
      $pAttr = $cmd.parameters["$k"].attributes | `
        ?{$_.TypeId.name -match "ParameterAttribute"}
      $helpmsg = $pAttr.HelpMessage
      if ($helpmsg -is [system.array]){$helpmsg = $helpmsg[0]}
      $vsAttr = $cmd.parameters["$k"].attributes | `
        ?{$_.TypeId.name -match "ValidateSetAttribute"}
      $vv = $vsAttr.validvalues
      $sets = @()
      foreach ($s in $cmd.parameters["$k"].parametersets.keys) {
        if ($s -ne "__AllParameterSets") {
          $sets += $s
        }
      }
      
      if ($isSwitch) {
        $type = "switch"
      } elseif ($name -match "password$") {
        $type = "password" 
      } elseif ($vv) {
        $type = "option"
        foreach ($v in $vv) {
          $options += $v
        }
      } elseif ($name -match "(text|property|url|workflow|body|command|list)") {
        $type = "textarea"
      } elseif (@("datastore", "portGroup", "vmName") -contains $name ) {
        $type = "selectText"
      } elseif ($name -match "file$") {
        $type = "file"
      } elseif ($name -match "time$") {
        $type = "time"
      } else {
        $type = $null
      }
      
      $parameter = new-object PSObject -Property @{
        name = $name
        helpmessage = $helpmsg
      }
      if ($options) { $parameter | add-member options $options }
      if ($pAttr.mandatory | Select -Unique) { $parameter | add-member mandatory 1 }
      if ($type) { $parameter | add-member "type" $type }
      if ($sets) { $parameter | add-member parametersets @($sets | sort) }
      $parameters += $parameter
    }
  }
  $command = new-object PSObject -Property @{
    script = $script
    developer = $developer
    description = $description
    synopsis = $synopsis
    functionalities = $functionalities
  }
  if ($parametersets) { 
    #$parametersets = $parametersets | get-unique
    $command | add-member parametersets ($parametersets | select -uniq | sort)
  }
  if ($parameters) { $command | add-member parameters $parameters}
  
  $command | convertto-json -depth 5 -compress | 
  set-content ($cmd.definition -replace ".ps1", ".json")
  
  return $command
}

$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
$commands = @()
gci $scriptPath\interfaces.ps1 -recurse | % {
  $commands += get-command $_.fullname 
}
$cmdSet = @()
foreach ($cmd in $commands) {
  $def = $cmd.definition.replace('.ps1','.json')
  if ((test-path $def) -and !$forceUpdate) {
    addToResult "Info - find existing command definition file $def"
    $cmdSet += (get-content $def) -join "`n" | convertfrom-json
  } else {
    $cmdSet += newCommand $cmd ($scriptPath + "\")
  }
}
$cmdSet | convertto-json -depth 5 -compress | set-content "$scriptPath\..\www\_def.json"
writeResult
