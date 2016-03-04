<?php
/* Author: Jian Liu, whirls9@hotmail.com */
$codeArray = array(
  "4000" => "Missing parameters",
  "4001" => "Fail - connect to server",
  "4002" => "Fail - connect to VC",
  "4003" => "Fail - get VM",
  "4004" => "Fail - get snapshot",  
  "4005" => "Fail - open page",
  "4006" => "Fail - find installer", 
  "4007" => "Fail - VMware Tools is not running",
  "4008" => "Fail - find snapshot",
  "4009" => "Fail - restore snapshot",
  "4010" => "Fail - delete snapshot",
  "4011" => "Fail - create snapshot",
  "4012" => "Fail - find unique snapshot",
  "4013" => "Fail - initialize broker",
  "4014" => "Fail - invalid license",
  "4015" => "Fail - add VC to broker",
  "4016" => "Fail - pool already exists",
  "4017" => "Fail - add pool to broker",
  "4018" => "Fail - run VM script",
  "4019" => "Fail - copy file",
  "4020" => "Fail - find desktop",
  "4021" => "Fail - find user",
  "4022" => "Fail - find a desktop assigned to user",
  "4023" => "Fail - update VMware Tools",
  "4024" => "Fail - add broker license",
  "4025" => "Fail - add transfer server",
  "4026" => "Fail - find transfer server",
  "4027" => "Fail - remove transfer server",
  "4028" => "Fail - find internal cmdlets",
  "4029" => "Fail - add standalone composer",
  "4030" => "Fail - find VC",
  "4031" => "Fail - add composer domain",
  "4032" => "Fail - send file to remote machine",
  "4033" => "Fail - entitle pool",
  "4034" => "Fail - connect to remote Windows system",
  "4035" => "Fail - unknown product type",
  "4036" => "Fail - uninstall application",
  "4037" => "Fail - download file",
  "4038" => "Fail - install",
  "4039" => "Fail - create new virtual machine",
  "4040" => "Fail - find build",
  "4041" => "Fail - set event database",
  "4042" => "Fail - create AD forest",
  "4043" => "Fail - join machine to domain",
  "4044" => "Fail - upgrade Powershell",
  "4045" => "Fail - create AD domain",
  "4046" => "Fail - update firmware",
  "4047" => "Fail - add farm",
  "4048" => "Fail - delete farm",
  "4049" => "Fail - add RDS server to farm",
  "4050" => "Fail - remove RDS server from farm",
  "4051" => "Fail - add application",
  "4052" => "Fail - delete application",
  "4053" => "Fail - entitle application",
  "4054" => "Fail - set HTML access",
  "4055" => "Fail - create desktop pool",
  "4056" => "Fail - set pool display name",
  "4400" => "Fail - execution timeout",
  "4444" => "Fail - unknown error occurred",
  "4445" => "Fail - run Powershell script",
  "4446" => "Fail - find script",
  "4488" => "Success - no error occurred"
);

function getIpAddress() {
  $ipaddress = '';
  if (getenv('HTTP_CLIENT_IP'))
    $ipaddress = getenv('HTTP_CLIENT_IP');
  else if(getenv('HTTP_X_FORWARDED_FOR'))
    $ipaddress = getenv('HTTP_X_FORWARDED_FOR');
  else if(getenv('HTTP_X_FORWARDED'))
    $ipaddress = getenv('HTTP_X_FORWARDED');
  else if(getenv('HTTP_FORWARDED_FOR'))
    $ipaddress = getenv('HTTP_FORWARDED_FOR');
  else if(getenv('HTTP_FORWARDED'))
    $ipaddress = getenv('HTTP_FORWARDED');
  else if(getenv('REMOTE_ADDR'))
    $ipaddress = getenv('REMOTE_ADDR');
  else
    $ipaddress = 'UNKNOWN';    
  
  if ($ipaddress == '::1')
    $ipaddress = '0.0.0.0';

  return $ipaddress;
}

function missParamNotice($file=0) {
  global $target;
  header("return-code:4000");
  $content = "Missing parameters";
  if ($file) { $content .= " - fail to upload file"; }
  $error = array("time" => date("Y-m-d H:i:s"), 
    "content" => $content,
    "type" => "error");
  $target["output"] = array(array($error));
  $target["returnCode"] = 4000;
}

function missScriptNotice($script) {  
  header("return-code:4446");
  $error = array("time" => date("Y-m-d H:i:s"), 
    "content" => "find script " . $script,
    "type" => "error");
  $result = array("output" => array($error), "returnCode" => "4446");
  echo json_encode($result);  
}

function callCmd($cmd) {
  global $target, $codeArray; 
  exec($cmd,$result,$exitcode);
  
  $verbose = preg_grep("/^VERBOSE: /", $result);
  $pos = key($verbose);
  if ($pos != 0) {
    $target["rawoutput"] = array_slice($result,0,$pos);
  }
  $result = array_slice($result,$pos);
  $result = implode("",str_replace("VERBOSE: ","",$result));
  $target["output"] = json_decode($result);
  
  if (strpos($result, "Fail - ") === FALSE) {
    header("return-code:4488");
    $target["returncode"] = 4488; 
  } else {
    $isKnown = false;
    while ($errType = current($codeArray)){
      if (strpos($result, $errType) > 0){
        header("return-code:" . key($codeArray));
        $target["returncode"] = key($codeArray);
        $isKnown = true;
        break;
      }
      next($codeArray);
    }
    if ($isKnown === false) {
      header("return-code:4444");
      $target["returncode"] = 4444;
    }
  }
}

function searchCommand($allCommands, $script) {
  foreach($allCommands as $command) {
    if(isset($command['script']) && strcasecmp($command['script'], $script) == 0) {
       return $command;
    }
  }
  return null;
}

$src = json_decode(file_get_contents("../sources.json"), true);
$commands = array();
foreach($src as $name=>$url) {
  $def = file_get_contents($url);
  if ($def === false) { 
    continue;
  } else {
    $cmds = json_decode($def, true);
  }
  foreach ($cmds as &$cmd) {
    $cmd['synopsis'] = $cmd['synopsis'] . ' ( ' . $name . ' )';
  }
  $commands = array_merge_recursive( $commands, $cmds );
}

$req = array_change_key_case($_REQUEST, CASE_LOWER);
$script = $req["script"];
$clientIp = getIpAddress();
$hisid = $req["hisid"];

if ($hisid != "") {
  $mongoquery = "mongo.exe localhost:27017/webcmd --eval \"db['history'].find({_id:ObjectId('" . $hisid . "')},{_id:0})\"";
  $log = shell_exec($mongoquery);
  $log = implode("\n", array_slice(explode("\n", $log), 2));
  echo $log;
} elseif ( $script == ""){
  echo json_encode($commands);
} elseif ($script == "showReturnCode") {
  echo json_encode($codeArray);
} else {
  $target = searchCommand($commands, $script);
  if (count($target) == 0){
    missScriptNotice($script);
  } else {
    $t0 = microtime(true);
    header("Content-type:application/json");
    $params = &$target['parameters'];
    $missParam = false;
    $missFile = false;
    $paramSeparator = " -";
    if ( preg_match('/\.py$/',$script) ) {
      $pyPath = realpath('../python/');
      chdir($pyPath);
      $cmd = "python .\\" . $script ;      
    } elseif ( preg_match('/\.rb$/',$script) ) {
      $rbPath = realpath('../ruby/');
      chdir($rbPath);
      $cmd = "ruby .\\" . $script;
      $paramSeparator = " --";
    } elseif ( preg_match('/\.pl$/',$script) ) {
      $rbPath = realpath('../perl/');
      chdir($rbPath);
      $cmd = "perl .\\" . $script ;
      $paramSeparator = " --";
    } else {
      $psPath = realpath('../powershell/');
      chdir($psPath);
      $cmd = "set runFromWeb=true & c:\\windows\\sysnative\\windowspowershell\\v1.0\\powershell.exe -noninteractive .\\exec.ps1 " . $script;
    }
    foreach($params as &$param){
      $name = strtolower((string)$param["name"]);
      if ($req[$name]) { $param["value"] = $req[$name]; }
      //if ($param["mandatory"] == 1 && $req[$name] == "" && $_FILES[$name] == "") {
      //  $missParam = true;
      //}
      if ($_FILES[$name] != "") {
        if($_FILES[$name]["error"] > 0) {  
          if ($param["mandatory"] == 1 ) {$missFile = true;}
        } else {
          $folder = "../www/upload/" . $clientIp;
          mkdir($folder, 0700);
          $fileName = $folder . "/" . $_FILES[$name]["name"];
          move_uploaded_file($_FILES[$name]["tmp_name"], $fileName);
          $cmd .= $paramSeparator . $name . " '" . realpath($fileName) . "'"; 
        }
      }
      if ($req[$name] != "") {
        $cmd .= $paramSeparator . $name . " " . urlencode($req[$name]); 
      }
    }
    if ($req["method"] != "") {
      $cmd .= $paramSeparator . $req["method"];
      $target["method"] = $req["method"];
    }

    if ($missParam) {
      missParamNotice();
    } elseif ($missFile) {
      missParamNotice(1);
    } else {      
      $cmd .= " <nul";
      $cmd .= " 2>&1";
      callCmd($cmd);
    }
    
    $t1 = microtime(true);
    $target["executiontime"] = sprintf("%.1f seconds", $t1 - $t0);
    $user = get_current_user();
    $userAgent = $_SERVER['HTTP_USER_AGENT'];
    $userAddr = $clientIp;
    $time = time();
    $target["user"] = $user;
    $target["useragent"] = $userAgent;
    $target["useraddr"] = $userAddr;
    $target["time"] = date('Y-m-d H:i:s',$time);

    //echo htmlspecialchars(json_encode($target), ENT_NOQUOTES);
    echo json_encode($target);
    if (!$missParam && $script != "History\\interfaces.ps1") {
      $script = preg_replace('/https?:\/\//', '', $script);
      $filename = '../www/history/' . $user . '/' . $userAddr . '/' . $script . '/' . $target["returncode"];
      $filename .=  '/output-' . $time . '.json';
      $dirname = dirname($filename);
      if (!is_dir($dirname)) {mkdir($dirname, 0755, true);}
      file_put_contents($filename, json_encode($target));
      shell_exec("mongoimport.exe --db webcmd --collection history --file " . $filename);
    }
  }
}
?>
