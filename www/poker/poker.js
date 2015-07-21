/*
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
*/

// Author: Jerry Liu, liuj@vmware.com

function loadXMLDoc(filename){
  var data;
  $.ajax({
    type: "GET",
    url: filename,
    async: false,
    dataType: 'xml'
  })
  .success(function (content) {
    data = content;
  })
  return data;
}

function transformXml(xml, xsl) {
  xsltProcessor = new XSLTProcessor();
  xsltProcessor.importStylesheet(xsl);
  html = xsltProcessor.transformToFragment(xml, document);
	return html;
}

function addRow(curRow){
  var curRowPos = curRow.index();
  var curGroup = $(xml).find("group").eq(curRowPos);
  curGroup.after(groupXml); 
  var row = $(transformXml($.parseXML(groupXml),xsl)).find("div.row");
  curRow.after(row);
  row.hide().show('slow');
  drawCard();
}

function delRow(curRow){
  var curRowPos = curRow.index();
  var curGroup = $(xml).find("group").eq(curRowPos);
  curGroup.remove(); 
  curRow.hide("slow",function(){
    curRow.remove();
  });
}

function orderRow(curRow, orderIcon){
  var curRowPos = curRow.index();
  var curGroup = $(xml).find("group").eq(curRowPos);
  if (orderIcon.hasClass("fa-cogs")) {
    curGroup.attr("order", "parallel");
  }
  else {
    curGroup.attr("order", "serial");
  }
}

function addCard(curCard){
  var curCardPos = curCard.index();
  var curRowPos = curCard.parent().parent().index();
  var curCmd = $(xml).find("group").eq(curRowPos).find("cmd").eq(curCardPos);
  curCmd.after(cmdXml); 
  var card = $(transformXml($.parseXML(cmdXml),xsl)).find("div.card");
  curCard.after(card);
  card.hide().show('slow');
  drawCard();
}

function delCard(curCard){
  var curCardPos = curCard.index();
  var curRowPos = curCard.parent().parent().index();
  var curCmd = $(xml).find("group").eq(curRowPos).find("cmd").eq(curCardPos);
  curCmd.remove(); 
  curCard.hide("slow",function(){
    curCard.remove();
  });
}

function drawCard(){
  $( ".pageData" ).sortable({
    start: function(e, info) {
      var oldRowPos = info.item.index();
      var oldGroup = $(xml).find("group").eq(oldRowPos);
      tempGroup = oldGroup.clone();
      oldGroup.remove();
    },
    stop: function(e, info) {
      var newRowPos = info.item.index();
      if (newRowPos == 0 ) {
        $(xml).find("group").eq(0).before(tempGroup);
      }
      else {
        $(xml).find("group").eq(newRowPos - 1).after(tempGroup);
      }
      console.log(xml);
    }
  }).disableSelection();
  
  $( ".rowData").sortable({
    connectWith: ".rowData",
    start: function(e, info) {
      var oldCardPos = info.item.index();
      var oldRowPos = info.item.parent().parent().index();
      var oldCmd = $(xml).find("group").eq(oldRowPos).find("cmd").eq(oldCardPos);
      tempCmd = oldCmd.clone();
      oldCmd.remove();
    },
    stop: function(e, info) {
      var newCardPos = info.item.index();
      var newRowPos = info.item.parent().parent().index();
      if ($(xml).find("group").eq(newRowPos).find("cmd").length == 0) {
        $(xml).find("group").eq(newRowPos).append(tempCmd);
      }
      else {
        if (newCardPos == 0 ) {
          $(xml).find("group").eq(newRowPos).find("cmd").eq(0).before(tempCmd);
        }
        else {
          $(xml).find("group").eq(newRowPos).find("cmd").eq(newCardPos - 1).after(tempCmd);
        }
      }
    }
  }).disableSelection();
}

function runPage(){
  var pageQueueName = "pageQueue";
  $(document).clearQueue(pageQueueName);
  $(".card").removeClass("pass fail");
  var superGroup = $(xml).find("supergroup").eq(0);
  if (superGroup.attr("order") === "parallel") {
    $(".page").find(".row").each(function() {
      var row = $(this);
      runRow(row);
    });
  }  
  else {
    $(".page").find(".row").each(function() {
      var row = $(this);
      $(document).queue(pageQueueName, function() {
        runRow(row, pageQueueName);
      });
    });
    $(document).dequeue(pageQueueName);
  }
}

function runRow(row, qName) {
  if (row.hasClass("disabled")) {
    if (typeof qName !== "undefined") {
      $(document).dequeue(qName);
    } 
    return;
  }
  var rowPos = row.index();
  var group = $(xml).find("group").eq(rowPos);
  //var cards = row.find(".card");
  var cmds = group.find("cmd");
  $(row).find(".card").removeClass("pass fail");
  if (group.attr("order") === "parallel") {
    $(row).find(".card").each(function(){
      var card = $(this);
      runCard(card);
    });
  }
  else {  
    var rowQueueName = "group_" + rowPos;
    $(document).clearQueue(rowQueueName);
    $(row).find(".card").each(function() { 
      var card = $(this);  
      $(document).queue(rowQueueName, function() {
        runCard(card, rowQueueName); 
      });
    });
    $(document).dequeue(rowQueueName);
  }
  if (typeof qName !== "undefined") {
    var interval = null;
    interval = setInterval(function(){
      var enabled = row.find(".card").not(".disabled").length;
      var failed = $(row).find(".fail").length;
      var passed = $(row).find(".pass").length;
      if (failed > 0) {
        $(document).clearQueue(qName);
        clearInterval(interval);
      } 
      else if ( enabled === passed ) {
        $(document).dequeue(qName);
        clearInterval(interval);
      }
    }, 500);
  }
}

function runCard(card, qName) {
  if (card.hasClass("disabled")) {
    if (typeof qName !== "undefined") {
      $(document).dequeue(qName);
    } 
    return;
  }
  var rowPos = card.parent().parent().index();
  var cardPos = card.index();
  var cmd = $(xml).find("group").eq(rowPos).find("cmd").eq(cardPos);
  card.removeClass("run pass fail").addClass("run");
  var formData = new FormData();
  cmd.find('parameter').each(function(){
    var fieldName = $(this).attr('name');
    if ($(this).attr('type') != 'file') {
      var fieldValue = $(this).attr('value');
    } else {
      var fieldValue = globalVariable[$(this).attr('value')];
    }
    formData.append(fieldName,fieldValue);
  });
  $.ajax({
    url: '/webcmd.php?command=' + cmd.find('command').attr('name'),
    type: 'POST',
    data: formData,
    async: true,
    cache: false,
    contentType: false,
    processData: false
  })
  .success(function(result){
    var returnCode = $(result).find('returnCode').text();
    var execTime = $(result).find('executiontime').text();
    cmd.find('command').children().detach();
    cmd.find('command').append($(result).find("webcommander")[0].innerHTML);
    if (returnCode === "4488") {
      card.removeClass("run pass fail").addClass("pass");
      if (typeof qName !== "undefined") {
        $(document).dequeue(qName);
      }
    } else {
      card.removeClass("run pass fail").addClass("fail");
      if (typeof qName !== "undefined") {
        $(document).clearqueue(qName);
      }
    }
    card.find("div.execTime").text(execTime);
    if ($("#cmdDialog").dialog( "isOpen" ) === true) {
      showCard(card);
    }
  })
  .fail(function(){
    card.removeClass("run pass fail").addClass("fail");
    if (typeof qName !== "undefined") {
      $(document).clearqueue(qName);
    }
  })
}

function showCard(curCard) {
  var curRowPos = curCard.parent().parent().index();
  var curCardPos = curCard.index();
  var curCmd = $(xml).find("group").eq(curRowPos).find("cmd").eq(curCardPos);  
  $( "#cmdDialog" ).html(select_cmd + '<hr/><div id="cmdDetail"></div>');
  $( "#cmdDialog" ).dialog({
    width:1024,
    height:768,
    modal:true,
    dialogClass: 'transparent',
    title: 'Command Detail',
    buttons:{
      "Save": function(){
        var selectCmd = $('#cmdDialog').find('.cmdlist').val();
        var selectCmdXml = $(allCmdXml).find('command').filter(function() {
          return $(this).attr('name') == selectCmd;
        });
        selectCmdXml.find("parameter").each(function(){
          var field = $("#" + $(this).attr("name"));
          if (field.attr("type") != "file") {
            $(this).attr('value', field.val());
          } else {
            var fileVarName = 'f_' + curRowPos + '_' + curCardPos; 
            globalVariable[fileVarName] = field[0].files[0];
            $(this).attr('value', fileVarName);
          }
        });
        if (selectCmdXml[0].xml){
          selectCmdXml = selectCmdXml[0].xml;
        } 
        else {
          selectCmdXml = selectCmdXml[0].outerHTML;
        }	
        curCmd.empty();
        curCmd.append(selectCmdXml);
        curCard.find(".cmdDesc").text(selectCmd);
        curCard.find(".execTime").text("0.0 seconds");
        $("#cmdDialog").dialog("close");
        return false;
      },
      "Execute": function(){
        $(":button:contains('Save')").click();
        $(":button:contains('Execute')").prop("disabled", true).addClass("ui-state-disabled running");
        setInterval(function() {
          $(":button.running").effect('fade',1000)
        }, 1000);
        runCard(curCard);
        return false;
      }
    }
  });
  var curCmdXml = curCmd.find('command');
  if (curCmdXml.length != 0) {
    $("#cmdDetail").replaceWith(transformXml($.parseXML(curCmdXml[0].outerHTML), cmdXsl));
    $("#cmdDetail").tabs();
    $(".cmdlist").find("option[value='" + curCmd.find("command").attr("name") + "']")
      .attr("selected","selected");
  }
	return false;
}

function exportXml(xmlstring) {
  //$( "#cmdDialog" ).html('<pre id="exportxml"></pre>');
  //$( '#exportxml' ).text( xmlstring );
  $( "#cmdDialog" ).html('<textarea id="xmltext" wrap="off">' + xmlstring + '</textarea>');
  $( "#cmdDialog" ).dialog({
    width:1024,
    height:768,
    modal:true,
    dialogClass: 'transparent',
    title: 'Export XML',
    buttons:{}
  });
	return false;
}

function importXml() {
  $( "#cmdDialog" ).html('<textarea id="xmltext" wrap="off"></textarea>');
  $( "#cmdDialog" ).dialog({
    width:1024,
    height:768,
    modal:true,
    dialogClass: 'transparent',
    title: 'Import XML',
    buttons:{
      "Import": function(){
        var newxml = $.parseXML($("#xmltext").val());
        $(xml).find("supergroup").append($(newxml).find("supergroup").children());
        console.log(xml);
        $('body').html(transformXml(xml, xsl));
        $(".card").hide().show("slow");
        drawCard();
        return false;
      }
    }
  });
	return false;
}

xsl = loadXMLDoc("/poker/poker.xsl");
xml = $.parseXML($('#poker').text());
allCmdXml = loadXMLDoc("/webcmd.php");
cmdXsl = loadXMLDoc("/poker/command.xsl");
cmdXml = "<cmd>No command defined yet</cmd>";
groupXml = "<group>" + cmdXml + "</group>";
senderRow = null;
globalVariable = {};

select_cmd = '<select class="cmdlist"><option selected disabled>Select a command to run</option>';
var cmd_list = $(allCmdXml)
  .find('webcommander')
  .find('command[hidden!="1"]').filter('command[type!="workflow"]');

cmd_list = $(cmd_list)
  .sort(function(a, b){
    var x = $(a).find('functionality').first().text() + $(a).attr('synopsis');
    var y = $(b).find('functionality').first().text() + $(b).attr('synopsis');
    return x == y ? 0 : x < y ? -1 : 1
  })
  .each(function(){
    select_cmd += '<option value="' + $(this).attr('name') + '">' + $(this).find('functionality').first().text() + " > " + $(this).attr('synopsis') + '</option>';
  }); 
select_cmd += '</select>';

$(function() {
  $('body').html(transformXml(xml, xsl));;
  $(".card").hide().show("slow");
  drawCard();
  
  $("body").on('change', '.cmdlist', function(){ 
    var selectCmd = $(this).val();
		var selectCmdXml = $(allCmdXml).find('command').filter(function() {
      return $(this).attr('name') == selectCmd;
    });
    if (selectCmdXml[0].xml){
      selectCmdXml = selectCmdXml[0].xml;
    } 
    else {
      selectCmdXml = selectCmdXml[0].outerHTML;
    }  
    $("#cmdDetail").replaceWith(transformXml($.parseXML(selectCmdXml), cmdXsl));
    $("#cmdDetail").tabs();
  });
  
  $("body").on('click', '.addRow', function(){ 
		var curRow = $(this).parents('div.row:first');
		addRow(curRow);
	});
  
  $("body").on('click', '.delRow', function(){ 
		var curRow = $(this).parents('div.row:first');
		delRow(curRow);
	});
  
  $("body").on('click', '.addCard', function(){ 
		var curCard = $(this).parents('div.card:first');
		addCard(curCard);
	});
  
  $("body").on('click', '.delCard', function(){ 
		var curCard = $(this).parents('div.card:first');
		delCard(curCard);
	});
  
  $("body").on('click', '.showCard', function(){ 
		var curCard = $(this).parents('div.card:first');
		showCard(curCard);
	});
  
  $("body").on('click', '.exportPage', function(){ 
		exportXml(new XMLSerializer().serializeToString(xml));
	});
  
  $("body").on('click', '.importPage', function(){
    importXml();
  });
  
  $("body").on('click', '.orderRow', function(){ 
		var curRow = $(this).parents('div.row:first');
		$(this).toggleClass("fa-cog fa-cogs");
    orderRow(curRow, $(this));
	});
  
  $("body").on('click', '.orderPage', function(){ 
		$(this).toggleClass("fa-cog fa-cogs");
    var superGroup = $(xml).find("supergroup").eq(0);
    if ($(this).hasClass("fa-cogs")) {
      superGroup.attr("order", "parallel");
    }
    else {
      superGroup.attr("order", "serial");
    }
    console.log(superGroup);
	});
  
  $("body").on('click', '.disable', function(){ 
		$(this).toggleClass("fa-toggle-on fa-toggle-off");
    var item = $(this).parent().parent();
    item.removeClass("run pass fail").toggleClass("disabled");
    if (item.hasClass("card")) {
      console.log("iscard");
      var itemCardPos = item.index();
      var itemRowPos = item.parent().parent().index();
      var itemCmd = $(xml).find("group").eq(itemRowPos).find("cmd").eq(itemCardPos);
      itemCmd.attr("disabled", "true");
    } 
    else if (item.hasClass("row")) {
      console.log("isrow");
      var itemRowPos = item.parent().parent().index();
      var itemCmd = $(xml).find("group").eq(itemRowPos);
      itemCmd.attr("disabled", "true");
    }
	});
  
  $("body").on('click', '.runRow', function(){ 
		var curRow = $(this).parents('div.row:first');
		runRow(curRow);
	});
  
  $("body").on('click', '.runPage', function(){ 
		runPage();
	});
});