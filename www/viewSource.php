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

// Author: Jerry Liu, liuj@vmware.com

header("Content-type:text/html");
$output = '<html>';
$output .= '<head>';
$output .= '<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />';
$output .= '<title>webCommander Source Code Viewer</title>';
$output .= '<script type="text/javascript" src="//agorbatchev.typepad.com/pub/sh/3_0_83/scripts/shCore.js"></script>';
$output .= '<script type="text/javascript" src="//agorbatchev.typepad.com/pub/sh/3_0_83/scripts/shBrushPowerShell.js"></script>';
$output .= '<script type="text/javascript" src="//agorbatchev.typepad.com/pub/sh/3_0_83/scripts/shBrushPython.js"></script>';
$output .= '<script type="text/javascript" src="//agorbatchev.typepad.com/pub/sh/3_0_83/scripts/shBrushRuby.js"></script>';
$output .= '<link type="text/css" rel="stylesheet" href="//agorbatchev.typepad.com/pub/sh/3_0_83/styles/shCoreDefault.css"/>';
$output .= '<script type="text/javascript">SyntaxHighlighter.all()</script>';
$output .= '</head>';
$output .= '<body style="background: white; font-family: Helvetica">';

$scriptName = $_REQUEST["scriptName"];
if ( preg_match('/\.py$/',$scriptName) ) {
  $output .= '<pre class="brush: python;">';
  $output .= file_get_contents("../python/" . $scriptName);
} elseif ( preg_match('/\.rb$/',$scriptName) ) {
  $output .= '<pre class="brush: ruby;">';
  $output .= file_get_contents("../ruby/" . $scriptName);
} elseif (file_exists("../powershell/" . $scriptName . ".ps1")) {
  $output .= '<pre class="brush: powershell;">';
  $output .= file_get_contents("../powershell/" . $scriptName . ".ps1");
} else {
  $output .= '<pre class="brush: powershell;">';
  $output .= "Could not find script " . $scriptName . ".ps1";
}
$output .= '</pre>';
$output .= '</body>';
$output .= '</html>';
echo $output;
?>
