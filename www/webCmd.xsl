<?xml version="1.0" ?>
<!--
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
-->

<!-- Author: Jerry Liu, liuj@vmware.com -->
<xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
	<xsl:output method="html"/>
	
	<xsl:template match="webcommander">
		<html>
			<head>
			<title>webCommander</title>
				<meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
				<link href='//fonts.googleapis.com/css?family=Roboto+Condensed' rel='stylesheet' type='text/css' />
				<link href="webCmd.css" rel="stylesheet" type="text/css" />
				<link rel="stylesheet" href="//code.jquery.com/ui/1.9.2/themes/base/jquery-ui.css" />
				<script src="//code.jquery.com/jquery-1.8.3.js"></script>
				<script src="//code.jquery.com/ui/1.9.2/jquery-ui.js"></script>
				<script src="webCmd.js"></script>
				<!--script>
					function IsAttributeSupported(tagName, attrName) {
						var val = false;
						var input = document.createElement(tagName);
						if (attrName in input) {
							val = true;
						}
						delete input;
						return val;
					}
					if (!IsAttributeSupported("input", "list")) {
						alert("Please use an HTML 5 compatible browser, such as Firefox, Chrome, Opera and IE 10.");
						window.location="http://www.firefox.com";
					}
				</script-->
			</head>
			<body>
				<xsl:call-template name="header"/>
				<xsl:call-template name="returnCode"/>
				<xsl:if test="/webcommander/annotation">
					<xsl:call-template name="annotation"/>
				</xsl:if>
				<div id="container">
					<xsl:call-template name="parameters"/>
					<xsl:call-template name="result"/>
				</div>
			</body>
		</html>
	</xsl:template>
	
	<xsl:template name="header">
		<div id="logo">
			<a href="webcmd.php" class="logo">web<span>Commander</span></a>
		</div>
		<div id="commandname">
			Command Name: <i><xsl:value-of select="@cmd"/></i><br/>
			Developer: <i><a class="devName">
				<xsl:attribute name="href">
					<xsl:value-of select="concat('mailto:', @developer, '@vmware.com')"/>
				</xsl:attribute>
				<xsl:value-of select="@developer"/>
			</a></i><br/>
			Script: <i><a class="devName" target="_blank">
				<xsl:attribute name="href">
					<xsl:value-of select="concat('viewsource.php?scriptName=', @script)"/>
				</xsl:attribute>
				<xsl:value-of select="@script"/>
			</a></i>
		</div>
		<!--div id="commandname">Command Name: <i><xsl:value-of select="@cmd"/></i></div>
		<div id="developer">Developer: 
			<i><a class="devName">
				<xsl:attribute name="href">
					<xsl:value-of select="concat('mailto:', @developer, '@vmware.com')"/>
				</xsl:attribute>
				<xsl:value-of select="@developer"/>
			</a></i>
		</div>
		<div id="script">Script: 
			<i><a class="devName">
				<xsl:attribute name="href">
					<xsl:value-of select="concat('viewsource.php?scriptName=', @script)"/>
				</xsl:attribute>
				<xsl:value-of select="@script"/>
			</a></i>
		</div-->
	</xsl:template>
	
	<xsl:template name="returnCode">
		<div id="returnCode"><a href="webcmd.php?command=showReturnCode" class="code" target="_blank"><xsl:value-of select="returnCode"/></a></div>
	</xsl:template>
	
	<xsl:template name="annotation">
		<div id="dialog" title="Command Annotation"><xsl:copy-of disable-output-escaping="yes" select="annotation"/></div>
		<script>
			$(function() {
				var dialogWidth;
				if ($("#widthSetter").length) {
					dialogWidth = $("#widthSetter").width() + 24;
				} else {
					dialogWidth = 300;
				}
				//$( "#dialog" ).dialog("resize", "auto");
				$( "#dialog" ).dialog({width:dialogWidth});
			});
		</script>
	</xsl:template>
	
	<xsl:template name="parameters">
		<div class="round-corner">
			<center>
				<xsl:if test="parameters/parameter">
					<form id="form1" method="post" enctype="multipart/form-data" action="webcmd.php?command={@cmd}">
						<table id="paraTable">
							<tr>
								<th>Parameter</th>
								<th>Value</th>
								<th>Description</th>
							</tr>
							<xsl:for-each select="parameters/parameter">
								<xsl:call-template name="parameter"/>
							</xsl:for-each>
							<tr>
								<td colspan="3" style="text-align:right">
									<img id="imgWait" src="images/progress-bar.gif" style="vertical-align:middle; margin-right:20px; visibility:hidden;" />
									<input id="btnSubmit" type="button" value="Submit" />
								</td>
							</tr>
						</table>
					</form>
				</xsl:if>
				<xsl:if test="returnCode = '4488'">
					<h2>This command could also be called with the URL below</h2>
					<textarea cols="100"><xsl:value-of select="url"/></textarea>
				</xsl:if>
			</center>
		</div>	
		<script>
					$(function(){
						var effects=["blind","bounce","clip","drop","explode","fold","highlight","puff","pulsate","scale","shake","size","slide","transfer"];
						var randomnumber=Math.floor(Math.random()*15);
						var options = {};
						if ( effects[randomnumber] === "scale" ) {
							options = { percent: 0 };
						} else if ( effects[randomnumber] === "transfer" ) {
							options = { to: "#logo", className: "ui-effects-transfer" };
						} else if ( effects[randomnumber] === "size" ) {
							options = { to: { width: 200, height: 60 } };
						}
						$("#table").effect( effects[randomnumber], options, 500, callback );
				 
						function callback() {
							setTimeout(function() {
								$( "#table" ).removeAttr( "style" ).hide().fadeIn();
							}, 1000 );
						};
					});
		</script>
	</xsl:template>
	
	<xsl:template name="parameter">	
		<tr>
			<td class="style2-right">
				<xsl:choose>
					<xsl:when test="@optional = '0'">
						<font style="color:red"><xsl:value-of select="@name"/></font>
					</xsl:when>
					<xsl:otherwise>
						<xsl:value-of select="@name"/>
					</xsl:otherwise>
				</xsl:choose>
			</td>
			<td> 
				<xsl:choose>
					<xsl:when test="@type = 'uvsid'">
						<xsl:value-of select="@value"/>
					</xsl:when>
					<xsl:when test="@type = 'textarea'">
						<textarea id="{@name}" name="{@name}" cols="80" rows="20"><xsl:value-of select="@value"/></textarea>
					</xsl:when>
					<xsl:when test="@type = 'file'">
						<input type="file" id="{@name}" name="{@name}" size="60" />
					</xsl:when>
					<xsl:when test="@type = 'password'">
						<input type="password" id="{@name}" name="{@name}" size="40" />
					</xsl:when>
					<xsl:when test="@type = 'option'">
						<select name="{@name}" id="{@name}">
							<xsl:if test="@name = 'isoPath'">
								<xsl:attribute name="style">width:400px</xsl:attribute>
							</xsl:if>
							<xsl:for-each select="options/option">
								<xsl:choose>
									<xsl:when test="@value = ../../@value">
										<option value="{@value}" selected="selected"><xsl:value-of select="text()" /></option>
									</xsl:when>
									<xsl:otherwise>
										<option value="{@value}"><xsl:value-of select="text()" /></option>	
									</xsl:otherwise>
								</xsl:choose>
							</xsl:for-each>	
						</select>
					</xsl:when>
					<xsl:when test="@type = 'selectText'">
						<xsl:if test="@name = 'isoPath'">
							<input type="text" name="{@name}" list="{@name}" value="{@value}" size="60" placeholder="Double click or enter keyword here" />
						</xsl:if>
						<xsl:if test="@name != 'isoPath'">
							<input type="text" name="{@name}" list="{@name}" value="{@value}" size="40" placeholder="Double click here" />
						</xsl:if>
						<datalist id="{@name}">
							<xsl:for-each select="options/option">
								<option value="{@value}"><xsl:value-of select="text()" /></option>	
							</xsl:for-each>
						</datalist>
					</xsl:when>
					<xsl:otherwise>
						<input type="text" id="{@name}" name="{@name}" value="{@value}" size="40" />	
					</xsl:otherwise>
				</xsl:choose>
				<xsl:if test="@name = 'datastore'">
					<input type="button" id="btnGetDatastore" value="List Datastore" />
				</xsl:if>
				<xsl:if test="@name = 'portGroup'">
					<input type="button" id="btnGetPortGroup" value="List Port Group" />
				</xsl:if>
				<xsl:if test="@name = 'build'">
					<input type="button" id="btnGetBuild" value="List Build" />
				</xsl:if>
				<xsl:if test="@name = 'isoPath'">
					<br/><input type="button" id="btnGetMoreIso" value="Get more ISO" />
				</xsl:if>
			</td>
			<td class="style2-right"><xsl:value-of select="@description"/></td>
		</tr>
	</xsl:template>
					
	<xsl:template name="result">			
		<div id="result">
		<div class="round-corner-result">
			<h2>Result</h2>
			<xsl:if test="contains(result, 'Missing parameters')">
				<ul>
					<li><xsl:value-of select="result"/></li>
				</ul>
			</xsl:if>
			<xsl:if test="not(contains(result, 'Missing parameters'))">
				<ul>
					<xsl:for-each select="result/customizedOutput">
						<li><xsl:value-of select="text()" /></li>
					</xsl:for-each>
				</ul>
				<pre><xsl:value-of select="result/stdOutput" /></pre>
				<xsl:for-each select="result/stderr">
					<center>
					<table class="exceptionTable">
					<tr><th colspan="2">Exception occurred</th></tr>
					<tr><td>Exception Type</td><td><xsl:value-of select="exceptionType" /></td></tr>
					<tr><td>Fully Qualified Error ID</td><td><xsl:value-of select="fullyQualifiedErrorId" /></td></tr>
					<tr><td>Error Message</td><td><xsl:value-of select="errMessage" /></td></tr>
					<tr><td>Script Name</td><td><xsl:value-of select="scriptName" /></td></tr>
					<tr><td>Scripte Line Number</td><td><xsl:value-of select="scriptLineNumber" /></td></tr>
					</table>
					</center>
				</xsl:for-each>
				
				<xsl:for-each select="result/Objects/Object">
					<center>
					<table class="exceptionTable">
					<tr><th>Application</th><th>Vendor</th><th>Version</th></tr>
					<xsl:for-each select="./Property">
						<tr>
							<td><xsl:value-of select="./Property[1]"/></td>
							<td><xsl:value-of select="./Property[2]"/></td>
							<td><xsl:value-of select="./Property[3]"/></td>
						</tr>
					</xsl:for-each>
					</table>
					</center>
				</xsl:for-each>
				
				<xsl:for-each select="result/VmHosts/VmHost">
					<center>
					<table class="exceptionTable" width="50%">
					<tr><th width="20%">Property</th><th width="80%">Value</th></tr>
					<xsl:for-each select="./Property">
						<xsl:sort select="@Name"/>
						<tr>
							<td><xsl:value-of select="@Name"/></td>
							<td><xsl:value-of select="."/></td>
						</tr>
					</xsl:for-each>
					</table>
					</center>
				</xsl:for-each>
				
				<xsl:if test="result/vm">
					<center>
						<table class="exceptionTable">
							<tr><th>VM</th><th>Remote control via VMRC ( download <a href="download/vmrc.zip">here</a> )</th><th>Remote control via MSTSC</th></tr>
							<xsl:for-each select="result/vm">
								<tr>
									<td><xsl:value-of select="name" /></td>
									<td>c:\vmrc\vmware-vmrc.exe -h <xsl:value-of select="hostaddr"/> -d "<xsl:value-of select="vmdkpath"/>" -u root -p <xsl:value-of select="hostpassword"/></td>
									<td>mstsc /v:<xsl:value-of select="ip"/></td>
								</tr>
							</xsl:for-each>
						</table>
					</center>
				</xsl:if>
				
				<xsl:if test="result/datastore">
					<center>
						<table class="exceptionTable" width="60%">
							<tr><th>Name</th><th>Free Space GB</th><th>Capacity GB</th></tr>
							<xsl:for-each select="result/datastore">
								<tr>
									<td><xsl:value-of select="name" /></td>
									<td><xsl:value-of select="freespace"/></td>
									<td><xsl:value-of select="capacity"/></td>
								</tr>
							</xsl:for-each>
						</table>
					</center>
				</xsl:if>
				
				<xsl:if test="result/portGroup">
					<center>
						<table class="exceptionTable" width="60%">
							<tr><th>Name</th><th>VLAN ID</th><th>Virtual Switch</th></tr>
							<xsl:for-each select="result/portGroup">
								<tr>
									<td><xsl:value-of select="name" /></td>
									<td><xsl:value-of select="vlanId"/></td>
									<td><xsl:value-of select="virtualSwitchName"/></td>
								</tr>
							</xsl:for-each>
						</table>
					</center>
				</xsl:if>
				
				<xsl:if test="result/build">
					<center>
						<table class="exceptionTable">
							<tr><th>ID</th><th>Changeset</th><th>Release Type</th><th>Build Type</th><th>Start Time</th><th>End Time</th><th>BAT Result</th></tr>
							<xsl:for-each select="result/build">
								<tr>
									<td><xsl:value-of select="id" /></td>
									<td><xsl:value-of select="changeset"/></td>
									<td><xsl:value-of select="releasetype"/></td>
									<td><xsl:value-of select="buildtype"/></td>
									<td><xsl:value-of select="starttime"/></td>
									<td><xsl:value-of select="endtime"/></td>
									<td><xsl:value-of select="qaresult"/></td>
								</tr>
							</xsl:for-each>
						</table>
					</center>
				</xsl:if>
				
				<xsl:if test="result/resourcepool">
					<center>
						<table class="exceptionTable" width="60%">
							<tr><th>Name</th><th>ID</th><th>Path</th></tr>
							<xsl:for-each select="result/resourcepool">
								<tr>
									<td><xsl:value-of select="name" /></td>
									<td><xsl:value-of select="id"/></td>
									<td><xsl:value-of select="path"/></td>
								</tr>
							</xsl:for-each>
						</table>
					</center>
				</xsl:if>
				
				<xsl:if test="result/desktop">
					<center>
						<table class="exceptionTable" width="60%">
							<tr><th>Pool ID</th><th>Desktop Name</th><th>Assigned User (for dedicated pool)</th><th>State</th></tr>
							<xsl:for-each select="result/desktop">
								<xsl:sort select="poolid"/>
								<tr>
									<td><xsl:value-of select="poolid" /></td>
									<td><xsl:value-of select="desktopname" /></td>
									<td><xsl:value-of select="assigneduser" /></td>
									<td><xsl:value-of select="state" /></td>
								</tr>
							</xsl:for-each>
						</table>
					</center>
				</xsl:if>
				
				<xsl:if test="result/virtualmachine">
					<center>
						<table class="exceptionTable" width="60%">
							<tr><th>VM Name</th><th>Power State</th><th>IP</th><th>Snapshots</th></tr>
							<xsl:for-each select="result/virtualmachine">
								<tr>
									<td><xsl:value-of select="name" /></td>
									<td><xsl:value-of select="power" /></td>
									<td><xsl:value-of select="ip" /></td>
									<td>	
										<xsl:for-each select="snapshot">
											<xsl:value-of select="text()" />
											<xsl:if test="position() != last()"> | </xsl:if>
										</xsl:for-each>
									</td>
								</tr>
							</xsl:for-each>
						</table>
					</center>
				</xsl:if>
				
				<h2>Execution Time</h2>
				<ul>
					<li><xsl:value-of select="executiontime"/></li>
				</ul>
			</xsl:if>
		</div>
		</div>
	</xsl:template>
	
</xsl:stylesheet>