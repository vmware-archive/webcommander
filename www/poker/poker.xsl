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
  
  <xsl:template match="supergroup">
    <div class="page">
      <div class="pageMenu">
        <i class="fa fa-cog orderPage" title="Serial / Parallel"></i> .  
        <i class="fa fa-play runPage" title="Run"></i> . 
        <i class="fa fa-file-text importPage" title="Import"></i> . 
        <i class="fa fa-file-text-o exportPage" title="Export"></i>
      </div>
      <div class="pageData">
        <xsl:apply-templates />
      </div>
    </div>
    <div id="cmdDialog" />
  </xsl:template>
	
	<xsl:template match="group">
    <div class="row">
      <xsl:if test="@disabled='true'">
        <xsl:attribute name="class">
          <xsl:text>row disabled</xsl:text>
        </xsl:attribute>
      </xsl:if>
      <div class="rowMenu">
        <i class="fa fa-plus-square addRow" title="Add"></i> . 
        <i class="fa fa-minus-square delRow" title="Delete"></i> . 
        <i class="fa fa-cog orderRow" title="Serial / Parallel"></i> . 
        <i title="Enable / Disable">
          <xsl:attribute name="class">
            <xsl:text>disable fa </xsl:text>
            <xsl:choose>
              <xsl:when test="@disabled='true'">
                <xsl:text>fa-toggle-off </xsl:text>
              </xsl:when>
              <xsl:otherwise>
                <xsl:text>fa-toggle-on </xsl:text>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:attribute>
        </i> . 
        <i class="fa fa-play runRow" title="Run"></i> . 
        <i class="fa fa-file-text importRow" title="Import"></i> . 
        <i class="fa fa-file-text-o exportRow" title="Export"></i>
      </div>
      <div class="rowData">
        <xsl:apply-templates />
      </div>
    </div>
	</xsl:template>

	<xsl:template match="cmd">			
    <div>
      <xsl:attribute name="class">
        <xsl:text>card </xsl:text>
        <xsl:if test="command/returnCode='4488'">
          <xsl:text>pass </xsl:text>
        </xsl:if>
        <xsl:if test="command/returnCode!='4488'">
          <xsl:text>fail </xsl:text>
        </xsl:if>
        <xsl:if test="@disabled='true'">
          <xsl:text>disabled </xsl:text>
        </xsl:if>
      </xsl:attribute>
      <div class="cardMenu">
        <i class="fa fa-plus-circle addCard" title="Add"></i> . 
        <i class="fa fa-minus-circle delCard" title="Delete"></i> .
        <i class="fa fa-info-circle showCard" title="Detail"></i> . 
        <i title="Enable / Disable">
          <xsl:attribute name="class">
            <xsl:text>disable fa </xsl:text>
            <xsl:choose>
              <xsl:when test="@disabled='true'">
                <xsl:text>fa-toggle-off </xsl:text>
              </xsl:when>
              <xsl:otherwise>
                <xsl:text>fa-toggle-on </xsl:text>
              </xsl:otherwise>
            </xsl:choose>
          </xsl:attribute>
        </i>
      </div>
      <div class="cmdDesc balloon">
        <xsl:choose>
          <xsl:when test="command">
            <xsl:value-of select="command/@name" />
          </xsl:when>
          <xsl:otherwise>
            <xsl:value-of select="text()" />
          </xsl:otherwise>
        </xsl:choose>
      </div>
      <div class="execTime balloon right">
        <xsl:choose>
          <xsl:when test="command/executiontime!=''">
            <xsl:value-of select="command/executiontime" />
          </xsl:when>
          <xsl:otherwise>
            <xsl:text>0.0 seconds</xsl:text>
          </xsl:otherwise>
        </xsl:choose>
      </div>
    </div>
	</xsl:template>
</xsl:stylesheet>