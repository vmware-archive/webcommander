. ./utils.ps1

$script = $args[0]
if (test-path ".\$script") {
  $c = get-content $script -raw
} else {
  try {
    $c = (invoke-webrequest $script).content
  } catch {
    addToResult "Fail - find script $script"
    endError
  }
}

$params = @()
for ( $i = 1; $i -lt $args.count; $i++ ) {
  $param = [System.Net.WebUtility]::urldecode($args[$i])
  if ($param -notmatch '^-') {
    $param = "'" + $param.replace("'","''") + "'"
  }
  $params += $param
}

try {
  Set-Item -Path function:script:theFunction -Value $c
  iex "theFunction $params"
  addToResult "Success - run Powershell script $script"
} catch {
  addToResult "Fail - run Powershell script $script"
  addError
}

writeResult -verbose 4>&1
