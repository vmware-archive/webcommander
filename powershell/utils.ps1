$global:result = @()
$ErrorActionPreference = "stop"
$WarningPreference = 0
$runFromWeb = [boolean]$env:runFromWeb

function writeResult {
  if ($runFromWeb) {
    try {
      $global:result | convertto-json -depth 3 -compress | out-host
    } catch {
      $global:result 
      [Environment]::exit("1")
    }
  } else {
    $global:result | fl
  }
}

function addToResult {
  param($data,$type="msg")
  $output = @{
    "type" = $type;
    "time" = get-date -format "yyyy-MM-dd HH:mm:ss";
    "data" = $data
  }
  $global:result += $output
}

function endError {
  addToResult @{"message"=$_.exception.message; "code"=$_.scriptstacktrace} "err"
  endExec
}

function endExec {
  writeResult
  if ($runFromWeb) { [Environment]::exit("0") }
  else { exit }
}