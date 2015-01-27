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
				<link href="/webCmd.css" rel="stylesheet" type="text/css" />
				<link rel="stylesheet" href="//code.jquery.com/ui/1.9.2/themes/base/jquery-ui.css" />
				<script src="//code.jquery.com/jquery-1.8.3.js"></script>
				<script src="//code.jquery.com/ui/1.9.2/jquery-ui.js"></script>
				<script src="/webCmd.js"></script>
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
				<xsl:if test="/webcommander/description">
					<xsl:if test="returnCode = '4000'">
						<xsl:call-template name="description"/>
					</xsl:if>
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
			<a href="/webcmd.php" class="logo">web<span>Commander</span></a>
		</div>
		<div id="commandname">
			Command Name: <i><xsl:value-of select="@cmd"/></i><br/>
			Developer: <i><a class="devName">
				<xsl:attribute name="href">
					<xsl:value-of select="concat('mailto:', @developer)"/>
				</xsl:attribute>
				<xsl:value-of select="@developer"/>
			</a></i><br/>
			Script: <i><a class="devName" target="_blank">
				<xsl:attribute name="href">
					<xsl:value-of select="concat('/viewsource.php?scriptName=', @script)"/>
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
		<div id="returnCode"><a href="/webcmd.php?command=showReturnCode" class="code" target="_blank"><xsl:value-of select="returnCode"/></a></div>
	</xsl:template>
	
	<xsl:template name="description">
		<div id="dialog" title="Command Description"><xsl:copy-of disable-output-escaping="yes" select="description"/></div>
		<script>
			$(function() {
				var dialogWidth;
				if ($("#widthSetter").length) {
					dialogWidth = $("#widthSetter").width() + 24;
				} else {
					dialogWidth = 500;
				}
				$( "#dialog" ).dialog({width:dialogWidth});
			});
		</script>
	</xsl:template>
	
	<xsl:template name="parameters">
		<div class="round-corner">
			<center>
				<xsl:if test="parameters/parameter">
					<form id="form1" method="post" enctype="multipart/form-data" action="/webcmd.php?command={@cmd}">
						<table id="paraTable">
							<tr>
								<th>Parameter</th>
								<th>Value</th>
								<th>Help Message</th>
							</tr>
							<xsl:for-each select="parameters/parameter">
								<xsl:call-template name="parameter"/>
							</xsl:for-each>
							<tr>
								<td colspan="3" style="text-align:right">
									<img id="imgWait" src="/images/progress-bar.gif" style="vertical-align:middle; margin-right:20px; visibility:hidden;" />
									<input id="btnSubmit" type="button" value="Submit" />
									<input id="btnJson" type="button" value="JSON" />
									<input id="btnUrl" type="button" value="URL" />
								</td>
							</tr>
						</table>
					</form>
				</xsl:if>
			</center>
		</div>	
	</xsl:template>
	
	<xsl:template name="parameter">	
		<tr>
			<td class="style2-right">
				<xsl:choose>
					<xsl:when test="@mandatory = '1'">
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
						<textarea id="{@name}" name="{@name}"><xsl:value-of select="@value"/></textarea>
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
			<td class="style2-right"><xsl:value-of select="@helpmessage"/></td>
		</tr>
	</xsl:template>
					
	<xsl:template name="result">			
		<div id="result">
		<div class="round-corner-result">
			<h2>Result</h2>
			<ul>
				<xsl:for-each select="result/*">
					<xsl:choose>
						<xsl:when test="name() = 'customizedOutput'">
							<li><xsl:value-of select="text()"/></li>
						</xsl:when> 
						<xsl:when test="name() = 'stdOutput'">
							<pre><xsl:value-of select="text()" /></pre>
						</xsl:when>
						<xsl:when test="name() = 'separator'">
							<hr class="separator" />
						</xsl:when>
						<xsl:otherwise>
							<xsl:call-template name="pvTable"/>
						</xsl:otherwise>
					</xsl:choose>
				</xsl:for-each>
			</ul>
			<hr class="separator"/>
			<h2 align="right">Execution Time : <xsl:value-of select="executiontime"/></h2>
		</div>
		</div>
	</xsl:template>
	
	<xsl:template name='pvTable'>
		<center>
		<table class="pvTable">
			<tr>
				<th width="30%">Property</th>
				<th width="70%">Value</th>
			</tr>
			<xsl:for-each select="*">
				<tr>
					<td>
						<xsl:choose>
							<xsl:when test="@Name">
								<xsl:value-of select="@Name" />
							</xsl:when>
							<xsl:otherwise>
								<xsl:value-of select="name()"/>
							</xsl:otherwise>
						</xsl:choose>
					</td>
					<td>
						<xsl:choose>
							<xsl:when test="not(*)">
								<xsl:value-of select="text()" />
							</xsl:when>
							<xsl:otherwise>
								<xsl:call-template name="pvTable" />
							</xsl:otherwise>
						</xsl:choose>
					</td>
				</tr>
			</xsl:for-each>
		</table>
		</center>
	</xsl:template>
	
</xsl:stylesheet>