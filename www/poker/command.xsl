<?xml version="1.0" ?>
<!--
Copyright (c) 2012-2015 VMware, Inc.

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
	
	<xsl:template match="command">
		<div id="cmdDetail">
      <ul>
        <li><a href="#tab-param">Parameters</a></li>
        <li><a href="#tab-result">Result</a></li>
        <li><a href="#tab-return">Return Code</a></li>
        <li><a href="#tab-time">Execution Time</a></li>
      </ul>
			<xsl:call-template name="parameters"/>
			<xsl:call-template name="result"/>
      <xsl:call-template name="return"/>
      <xsl:call-template name="time"/>
		</div>
	</xsl:template>
	
	<xsl:template name="parameters">
		<div id="tab-param">
			<center>
				<xsl:if test="parameters/parameter">
					<form id="form1" method="post" enctype="multipart/form-data" action="/webcmd.php?command={@cmd}">
						<table id="paraTable">
							<xsl:for-each select="parameters/parameter">
							  <xsl:call-template name="parameter"/>
							</xsl:for-each>
						</table>
					</form>
				</xsl:if>
			</center>
		</div>	
	</xsl:template>
	
	<xsl:template name="parameter">	
		<tr>
			<th>
				<xsl:choose>
					<xsl:when test="@mandatory = '1'">
						<font style="color:red"><xsl:value-of select="@name"/></font>
					</xsl:when>
					<xsl:otherwise>
						<xsl:value-of select="@name"/>
					</xsl:otherwise>
				</xsl:choose>
			</th>
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
				<xsl:if test="@name = 'vmName'">
					<input type="button" id="btnGetVmName" value="List VM name" />
				</xsl:if>
				<xsl:if test="@name = 'build'">
					<input type="button" id="btnGetBuild" value="List Build" />
				</xsl:if>
				<xsl:if test="@name = 'isoPath'">
					<br/><input type="button" id="btnGetMoreIso" value="Get more ISO" />
				</xsl:if>
        <br/><span class="helpMsg"><xsl:value-of select="@helpmessage"/></span>
			</td>
		</tr>
	</xsl:template>
					
	<xsl:template name="result">			
		<div id="tab-result">
			<ul>
				<xsl:for-each select="result/*">
					<xsl:choose>
						<xsl:when test="name() = 'customizedOutput'">
							<li><xsl:value-of select="text()"/></li>
						</xsl:when> 
						<xsl:when test="name() = 'stdOutput'">
							<pre><xsl:value-of select="text()" /></pre>
						</xsl:when>
						<xsl:when test="name() = 'link'">
							<a target="_blank">
								<xsl:attribute name="href">
									<xsl:value-of select="url"/>
								</xsl:attribute>
								<xsl:value-of select="title"/>
							</a>
						</xsl:when>
						<xsl:when test="name() = 'separator'">
							<hr class="separator" />
						</xsl:when>
						<xsl:when test="name() = 'history'">
							<hr class="separator"/>
							<center><table id="hisTable">
								<thead><tr><th>Number</th><th>Time</th><th>User</th><th>User Address</th><th>Command name</th><th>Result code</th><th>File</th></tr></thead>
								<tbody>
								<xsl:for-each select="record">
									<xsl:sort select="time" order="descending" />
									<tr>
										<td><xsl:value-of select="position()" /></td>
										<td><xsl:value-of select="time"/></td>
										<td><xsl:value-of select="user"/></td>
										<td><xsl:value-of select="useraddr" /></td>
										<td><xsl:value-of select="cmdname"/></td>
										<td><xsl:value-of select="resultcode"/></td>
										<td>
											<a target="_blank">
												<xsl:attribute name="href">
													<xsl:value-of select="concat('/history/', user, '/', useraddr, '/', cmdname, '/', resultcode, '/', filename)"/>
												</xsl:attribute>
												<xsl:value-of select="filename"/>
											</a>
										</td>
									</tr>
								</xsl:for-each>
								</tbody>
							</table></center>
							<script>
								$(function(){
									$('#hisTable').DataTable();
								});
							</script>
						</xsl:when>
						<xsl:otherwise>
							<xsl:call-template name="pvTable"/>
						</xsl:otherwise>
					</xsl:choose>
				</xsl:for-each>
			</ul>
		</div>
	</xsl:template>
  
  <xsl:template name="return">
    <div id="tab-return">
			<h2><xsl:value-of select="returnCode"/></h2>
    </div>
  </xsl:template>
  
  <xsl:template name="time">
    <div id="tab-time">
			<h2><xsl:value-of select="executiontime"/></h2>
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