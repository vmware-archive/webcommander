$global:result = @()
$ErrorActionPreference = "stop"
$WarningPreference = 0
$runFromWeb = [boolean]$env:runFromWeb

function addError {
  addToResult @{"message"=$_.exception.message; "code"=$_.scriptstacktrace} "err"
}

function addSeparator {
  $output = @{"type" = "separator"}
  $global:result += $output
}

function addToResult {
  param($data,$type="msg")
  if ($type -eq "dataset") {
    if ($data -isnot [system.array]) {$data = @($data)}
  }
  $output = @{
    "type" = $type;
    "time" = get-date -format "yyyy-MM-dd HH:mm:ss";
    "data" = $data
  }
  $global:result += $output
}

function addToResult1 {
  param(
    [parameter(ValueFromPipeline=$True)]
    $data,
    
    $type="msg"
  )
  begin{}
  process {
    $output = @{
      "type" = $type;
      "time" = get-date -format "yyyy-MM-dd HH:mm:ss";
      "data" = $data
    }
    $global:result += $output
  }
  end{}
}

function endError {
  addError
  endExec 1
}

function endExec {
  param($code=0)
  writeResult
  if ($runFromWeb) { [Environment]::exit("$code") }
  else { exit $code }
}

function getFileList {
  param($fileUrl)
  $files = @()
  $fileList = @($fileUrl.split("`n") | %{$_.trim()})
  $wc = new-object system.net.webclient;  
  $fileList | % {
    if (test-path $_) {
      $files += $_
    } elseif (invoke-webrequest $_) {
      $fileName = ($_.split("/"))[-1]
      $path = resolve-path "..\www\upload"
      $wc.downloadfile($_, "$path\$fileName")
      $files += "$path\$fileName"
    }
  }
  return $files
}

function writeResult {
  if ($runFromWeb) {
    try {
      convertto-json @($global:result) -depth 3 -compress | write-verbose -verbose
    } catch {
      $global:result 
      [Environment]::exit("1")
    }
  } else {
    $global:result | fl
  }
}