<#
  .SYNOPSIS
    Generate command definition

  .DESCRIPTION
    This command generates _def.json.
    It parses all powershell scripts to get information from comment
    based help and parameter attributes.
    
  .FUNCTIONALITY
    JSON

  .NOTES
    AUTHOR: Jian Liu
    EMAIL: whirls9@hotmail.com
#>

foreach ($paramKey in $psboundparameters.keys) {
	$oldValue = $psboundparameters.item($paramKey)
	$newValue = [system.web.httputility]::urldecode("$oldValue")
	set-variable -name $paramKey -value $newValue
}

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
			$name = $cmd.parameters["$k"].name
			if ($name -in $commonParam){continue}
			$pAttr = $cmd.parameters["$k"].attributes | `
				?{$_.TypeId.name -match "ParameterAttribute"}
			$helpmsg = $pAttr.HelpMessage
			$vsAttr = $cmd.parameters["$k"].attributes | `
				?{$_.TypeId.name -match "ValidateSetAttribute"}
			$vv = $vsAttr.validvalues
      $sets = @()
      foreach ($s in $cmd.parameters["$k"].parametersets.keys) {
        if ($s -ne "__AllParameterSets") {
          $sets += $s
        }
      }
      
			if ($name -match "password$") {
				$type = "password" 
			} elseif ($vv) {
				$type = "option"
				foreach ($v in $vv) {
					$options += $v
				}
			} elseif ($name -match "(script|property|url|workflow|body)$") {
				$type = "textarea"
			} elseif (@("datastore", "portGroup", "vmName") -contains $name ) {
				$type = "selectText"
			} elseif ($name -match "file$") {
				$type = "file"
			} else {
        $type = $null
      }
      
      $parameter = new-object PSObject -Property @{
        name = $name
        helpmessage = $helpmsg
      }
      if ($options) { $parameter | add-member options $options }
      if ($pAttr.mandatory) { $parameter | add-member mandatory 1 }
      if ($type) { $parameter | add-member "type" $type }
      if ($sets) { $parameter | add-member parametersets $sets }
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
  if ($parametersets) { $command | add-member parametersets $parametersets}
  if ($parameters) { $command | add-member parameters $parameters}
  
	return $command
}

$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
$commands = @()
gci $scriptPath\interfaces.ps1 -recurse | % {
	$commands += get-command $_.fullname 
}
$cmdSet = @()
foreach ($cmd in $commands) {
	$cmdSet += newCommand $cmd ($scriptPath + "\")
}
$cmdSet | convertto-json -depth 5 -compress | set-content "$scriptPath\..\www\_def.json"
writeResult