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
	foreach (array('HTTP_CLIENT_IP', 'HTTP_X_FORWARDED_FOR', 'HTTP_X_FORWARDED', 'HTTP_X_CLUSTER_CLIENT_IP', 'HTTP_FORWARDED_FOR', 'HTTP_FORWARDED', 'REMOTE_ADDR') as $key) {
		if (array_key_exists($key, $_SERVER) === true) {
			foreach (explode(',', $_SERVER[$key]) as $ip) {
				if (filter_var($ip, FILTER_VALIDATE_IP) !== false) {
					return $ip;
				}
			}
		}
	}
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
	if ($exitcode != 0) {
    header("return-code:4445");
    $content = "Fail - run command";
    $error = array("time" => date("Y-m-d H:i:s"), 
      "data" => $content,
      "type" => "msg");
    $stdout = array("data" => implode("\n",$result),
      "type" => "raw");
    $target["output"] = array($error,$stdout);
    $target["returncode"] = 4445;	
	}	else {
    $result = $result[0];
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
}

function searchCommand($allCommands, $script) {
  foreach($allCommands as $command) {
    if(isset($command['script']) && strcasecmp($command['script'], $script) == 0) {
       return $command;
    }
  }
  return null;
}

$req = array_change_key_case($_REQUEST, CASE_LOWER);
$script = $req["script"];
$commands = json_decode(file_get_contents("_def.json"), true);

if ( $script == ""){
	header( 'Location: /index.html' );
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
      $cmd = "set runFromWeb=true & c:\\windows\\sysnative\\windowspowershell\\v1.0\\powershell.exe -noninteractive .\\" . $script;
    }
		$url = "http://" . $_SERVER['SERVER_NAME'] . ":" . $_SERVER['SERVER_PORT'] . "/webcmd.php?command=" . $command;
		foreach($params as &$param){
			$name = strtolower((string)$param["name"]);
      if ($req[$name]) { $param["value"] = $req[$name]; }
			//if ($param["mandatory"] == 1 && $req[$name] == "" && $_FILES[$name] == "") {
			//	$missParam = true;
			//}
			if ($_FILES[$name] != "") {
				if($_FILES[$name]["error"] > 0) {	
					if ($param["mandatory"] == 1 ) {$missFile = true;}
				} else {
					$clientIp = getIpAddress();
					$folder = "../www/upload/" . $clientIp;
					mkdir($folder, 0700);
					$fileName = $folder . "/" . $_FILES[$name]["name"];
					move_uploaded_file($_FILES[$name]["tmp_name"], $fileName);
					$cmd .= $paramSeparator . $name . " '" . realpath($fileName) . "'"; 
				}
			}
			if ($req[$name] != "") {
				$cmd .= $paramSeparator . $name . " " . urlencode($req[$name]); 
				$url .= "&" . $name . "=" . urlencode($req[$name]);
			}
		}
 
		header("url:" . $url);

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
		$userAddr = $_SERVER['REMOTE_ADDR'];
		$time = time();
		$target["user"] = $user;
		$target["useragent"] = $userAgent;
		$target["useraddr"] = $userAddr;
		$target["time"] = date('Y-m-d H:i:s',$time);

		//echo htmlspecialchars(json_encode($target), ENT_NOQUOTES);
    echo json_encode($target);
		if (!$missParam && $command != "showHistory") {
			$filename = '../www/history/' . $user . '/' . $userAddr . '/' . $script . '/' . $target["returncode"];
			$filename .=  '/output-' . $time . '.json';
			$dirname = dirname($filename);
			if (!is_dir($dirname)) {mkdir($dirname, 0755, true);}
			file_put_contents($filename, json_encode($target));
		}
	}
}
?>
