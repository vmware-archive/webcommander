$web = new-object net.webclient
# iex $web.downloadstring('http://bit.ly/1NOWEIH') # utils.ps1
. .\utils.ps1

$script = $args[0]
if (test-path ".\$script") {
  $c = get-content $script -raw
} else {
  try {
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
  $output = iex "theFunction $params"
  $output.message
} catch {
  addToResult "Fail - run Powershell script $script"
  endError
}