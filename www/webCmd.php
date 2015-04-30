<?php
/*
Copyright (c) 2012-2014 VMware, Inc.

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
*/

/* Author: Jerry Liu, liuj@vmware.com */
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
	"4013" => "Fail - initalize broker",
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

function missParamNotice() {
	global $xmloutput;
	header("return-code:4000");
	$xmloutput .= "<result><customizedOutput>[";
	$xmloutput .= date("Y-m-d H:i:s");
	$xmloutput .= "] Missing parameters</customizedOutput></result>";
	$xmloutput .= "<returnCode>4000</returnCode>";
}

function missFileNotice() {	
	global $xmloutput;
	header("return-code:4000");
	$xmloutput .= "<result><customizedOutput>[";
	$xmloutput .= date("Y-m-d H:i:s");
	$xmloutput .= "] Missing parameters - fail to upload file</customizedOutput></result>";
	$xmloutput .= "<returnCode>4000</returnCode>";
}

function cleanPsParam($string) {	
	$old = array("`", "'", '"', "$", " ");
	$new = array("``", "`'", '`"', "`$", "` ");
	return "'" . str_replace($old, $new, $string) . "'";
}

function callPs1($cmd) {
	global $xmloutput, $codeArray;
	exec($cmd,$result,$exitcode);
	foreach ($result as $line) {
		$output .= $line . "\r\n";
	}
	if ($exitcode != 0) {
		$output = "<stdOutput><![CDATA[" . $output . "]]></stdOutput>";
		$output .= "<customizedOutput> [";
		$output .= date("Y-m-d H:i:s") . "] Fail - run Powershell script</customizedOutput>";
	}	
	$xmloutput .= "<result>" . $output . "</result>";
	if (strpos($output, "] Fail - ") === FALSE) {
		header("return-code:4488");
		$xmloutput .= "<returnCode>4488</returnCode>";
	} else {
		$isKnown = false;
		while ($errType = current($codeArray)){
			if (strpos($output, $errType) > 0){
				header("return-code:" . key($codeArray));
				$xmloutput .= "<returnCode>" . key($codeArray) . "</returnCode>";
				$isKnown = true;
				break;
			}
			next($codeArray);
		}
		if ($isKnown === false) {
			header("return-code:4444");
			$xmloutput .= "<returnCode>4444</returnCode>";
		}
	}
}

$req = array_change_key_case($_REQUEST, CASE_LOWER);
$command = $req["command"];
$dom = new DOMDocument();
$dom->preserveWhiteSpace = false;
$dom->formatOutput = true; 
$dom->load("webcmd.xml", LIBXML_XINCLUDE | LIBXML_NOENT);
$dom->xinclude();
$xmloutput = "";

if ( $command == ""){
	$thedocument = $dom->documentElement;
	$list = $thedocument->getElementsByTagName('command');
	foreach ($list as $domElement){
		$scriptName = $domElement->getElementsByTagName('script')->item(0)->textContent;
		if (!file_exists("../powershell/" . $scriptName . ".ps1") and !file_exists("./" . $scriptName)) {
			#$thedocument->removeChild($domElement);
			$domElement->setAttribute("hidden","1");
		}
	}
	header("Content-type:text/xml");
	echo $dom->saveXML();
} elseif ($command == "showReturnCode") {
	echo "<pre>";
	print_r($codeArray);
	echo "</pre>";
	echo "<img src='images/webcmd_architecture.png' width='1000' height='700'>";
} else {
	$xml = simplexml_import_dom($dom);
	$query = '/webcommander/command[@name="' . $command . '"]';
	$target = $xml->xpath($query);
	if (count($target) == 0){
		$xmloutput .= "<script>alert('Could not find command \"" . $command . "\"!')</script>";
		$xmloutput .= "<script>document.location.href='webcmd.php'</script>";
		echo $xmloutput;
	} else {
		$t0 = microtime(true);
		$target = $target[0];
		header("Content-type:text/xml");
		//include("include/functionLib.php");
		$xmloutput .= '<?xml version="1.0" encoding="UTF-8" ?>';
		$xmloutput .= '<?xml-stylesheet type="text/xsl" href="/webCmd.xsl"?>';
		$scriptName = (string)$target->script;
		$xmloutput .= '<webcommander cmd="' . $command . '" developer="' . $target["developer"] . '" ';
		$xmloutput .= 'synopsis="' . $target["synopsis"] . '" script="' . $scriptName . '">';
		$description = $target->xpath("description");
		if ( $description ){$xmloutput .= $description[0]->asXML();}
		$xmloutput .= '<parameters>';
		$params = $target->xpath("parameters/parameter");
		$missParam = false;
		$missFile = false;
		$psPath = realpath('../powershell/');
		chdir($psPath);
		$cmd = "powershell .\\" . $scriptName . ".ps1";
		$url = "http://" . $_SERVER['SERVER_NAME'] . ":" . $_SERVER['SERVER_PORT'] . "/webcmd.php?command=" . $command;
		foreach($params as $param){
			$name = strtolower((string)$param["name"]);
			$param->addAttribute("value", $req[$name]);
			$xmloutput .= $param->asXML();
			if ((string)$param["mandatory"] == "1" && $req[$name] == "" && $_FILES[$name] == "") {
				$missParam = true;
			}
			if ($_FILES[$name] != "") {
				//if($_FILES[$name]["size"] > 200000 or $_FILES[$name]["error"] > 0)
				if($_FILES[$name]["error"] > 0)
				{	
					if ($param["mandatory"] == "1" ) {$missFile = true;}
				} else {
					$clientIp = getIpAddress();
					$folder = "../www/upload/" . $clientIp;
					mkdir($folder, 0700);
					#$fileName = date("Ymd-his__") . $clientIp . "__" . $_FILES[$name]["name"];
					$fileName = $folder . "/" . $_FILES[$name]["name"];
					move_uploaded_file($_FILES[$name]["tmp_name"], $fileName);
					$cmd .= " -" . $name . " " . realpath($fileName); 
				}
			}
			if ($req[$name] != "") {
				$cmd .= " -" . $name . " " . urlencode($req[$name]); 
				$url .= "&" . $name . "=" . urlencode($req[$name]);
			}
		}
		//header("url:" . $url);
		$xmloutput .= '</parameters>';

		if ($missParam) {
			missParamNotice();
		} elseif ($missFile) {
			missFileNotice();
		} else {      
			$cmd .= " <nul";
			//$cmd .= " 2>&1";
			//$xmloutput .= '<cmd><![CDATA[' . $cmd . ']]></cmd>';
			callPs1($cmd);
		}
		
		//$xmloutput .= '<url><![CDATA[' . $url . ']]></url>';
		$t1 = microtime(true);
		$xmloutput .= sprintf("<executiontime>%.1f seconds</executiontime>", $t1 - $t0);
		$user = get_current_user();
		$userAgent = $_SERVER['HTTP_USER_AGENT'];
		$userAddr = $_SERVER['REMOTE_ADDR'];
		$time = time();
		$xmloutput .= "<user>" . $user . '</user>';
		$xmloutput .= "<useragent>" . $userAgent . '</useragent>';
		$xmloutput .= "<useraddr>" . $userAddr . '</useraddr>';
		$xmloutput .= "<time>" . date('Y-m-d H:i:s',$time) . '</time>';
		$xmloutput .= "</webcommander>";
		
		$dom->loadXML(utf8_encode($xmloutput));
		$dom->formatOutput = true;
		echo $dom->saveXML();
		if (!$missParam) {
			$xml = simplexml_import_dom($dom);
			$returncode = $xml->xpath('/webcommander/returnCode');
			$filename = '../www/history/' . $user . '/' . $userAddr . '/' . $command . '/' . $returncode[0];
			$filename .=  '/output-' . $time . '.xml';
			$dirname = dirname($filename);
			if (!is_dir($dirname)) {mkdir($dirname, 0755, true);}
			$dom->save($filename);
		}
	}
}
?>