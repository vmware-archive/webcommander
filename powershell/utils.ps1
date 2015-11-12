$global:result = @()
$ErrorActionPreference = "stop"
$WarningPreference = 0
$runFromWeb = [boolean]$env:runFromWeb

function addSeparator {
  $output = @{"type" = "separator"}
  $global:result += $output
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
      $global:result | convertto-json -depth 3 -compress | out-host
    } catch {
      $global:result 
      [Environment]::exit("1")
    }
  } else {
    $global:result | fl
  }
}