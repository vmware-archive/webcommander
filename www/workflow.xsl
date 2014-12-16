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
		<xsl:call-template name="result" />
	</xsl:template>
	
	<xsl:template name="result">			
		<div id="result">
			<xsl:if test="contains(result, 'Missing parameters')">
				<ul>
					<li><xsl:value-of select="result"/></li>
				</ul>
			</xsl:if>
			<xsl:if test="not(contains(result, 'Missing parameters'))">
				<ul>
				<xsl:for-each select="result/*">
					<xsl:choose>
						<xsl:when test="name() = 'customizedOutput'">
							<li><xsl:value-of select="text()"/></li>
						</xsl:when> 
						<xsl:when test="name() = 'stdOutput'">
							<pre><xsl:value-of select="text()" /></pre>
						</xsl:when>
						<xsl:otherwise>
							<xsl:call-template name="pvTable"/>
						</xsl:otherwise>
					</xsl:choose>
				</xsl:for-each>
				</ul>
			</xsl:if>	
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