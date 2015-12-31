<?php
/* Author: Jian Liu, whirls9@hotmail.com */

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
    $ipaddress = '1';

  return $ipaddress;
}

header("Content-type:html/txt");
$req = array_change_key_case($_REQUEST, CASE_LOWER);
$content = $req["content"];
$filename = $req["filename"];
$clientIp = getIpAddress();
$folder = "workflow/" . $clientIp . "/" . uniqid();
$file = $folder . "/" . $filename;
  
$dirname = dirname($file);
if (!is_dir($dirname)) {mkdir($dirname, 0755, true);}
file_put_contents($file, $content);

echo $file;
?>
