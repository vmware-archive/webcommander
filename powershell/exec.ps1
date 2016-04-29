. .\utils.ps1

$script = $args[0]
if (test-path ".\$script") {
  $c = get-content $script -raw
} else {
  try {
    $web = new-object net.webclient
    $c = $web.downloadstring($script)
  } catch {
    addToResult "Fail - read $script"
    endError
  }
}

$params = @()
for ( $i = 1; $i -lt $args.count; $i++ ) {
  $param = $args[$i]
  if ($param.gettype().name -eq "String") {
    $param = [system.web.httputility]::urldecode($param)
  }
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
