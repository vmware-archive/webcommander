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

$.fn.serializeObject = function(){
    var o = {};
	o["command"] = this.attr('name');
    var a = this.serializeArray();
    $.each(a, function() {
        if (o[this.name] !== undefined) {
            if (!o[this.name].push) {
                o[this.name] = [o[this.name]];
            }
            o[this.name].push(this.value || '');
        } else {
            o[this.name] = this.value || '';
        }
    });
    return o;
};

function addCommand(currentCommand){
	var $cmd = $('<div class="command"><p class="heading"><span class="orderNumber"></span>\
		' + select_cmd + '<span class="description"></span><span class="status"></span><span class="right"> \
		<input class="add" type="image" title="Add a new command" src="images/button-add-icon.png" /> \
		<input class="delete" type="image" title="Delete this command" src="images/button-delete-icon.png" /> \
		<input class="toggle" type="image" title="Toggle display" src="images/button-switch-icon.png" /> \
		<input class="onoff" type="image" title="Enable / Disable this command" src="images/button-on-icon.png" /></span></p>\
		<div class="body"><div class="content"></div><div class="detail"></div></div></div>');
	if (currentCommand.length != 0){
		currentCommand.after($cmd);
	} else {
		$cmd.appendTo($('#sortable'));
	}
	$cmd.hide().show('slow');
}

function populate(frm, data) {   
    $.each(data, function(key, value){  
		var $ctrl = $('[name='+key+']', frm);  
		switch($ctrl.attr("type")){  
			case "text" :   
			case "hidden":  
			case "password":
			case "textarea":  
				$ctrl.val(value); 
				$ctrl.trigger("change");
				break;   
			case "radio" : 
			case "checkbox":   
				$ctrl.each(function(){
					if($(this).attr('value') == value) {  $(this).attr("checked",value); } });   
				break; 
			case "select" :
				$ctrl.find('option[value="' + value + '"]').prop('selected',true);
				break;
		}  
    }); 
	if (data['wf_off']) {frm.parents('div.command').find('.onoff').trigger('click');}
}

function updateOrder(){
	$('div.command').each(function() {
		var cmd = $(this);
		var on = cmd.find('.orderNumber');
		on.empty();
		on.html(cmd.index() + 1);
	});
}

function addWorkflowFromJson(workflowJson) {
	workflowJson.forEach(function(command){
		if (command.description !== undefined && command.command == undefined) {
			var desc = '<div id="workflowDesc" title="Workflow Description">\
				' + command.description + '</div>';
			$('#sortable').after(desc);
			$( "#workflowDesc" ).dialog({width:600});
		} else {
			var currentCommand = $('div.command:last');
			addCommand(currentCommand);
			$('div.command:last')
				.find('.cmdlist')
				.find('option[value="' + command.command + '"]')
				.prop('selected',true)
				.change();	
			var form = $('div.command:last').find('form:first');
			populate(form,command);
		}
	});
	updateOrder();
	return false;
}

function addWorkflow(jsonString){
	var lines = jsonString.split("\n");
	for (var i in lines) {
		line = lines[i];
		if (line.charAt(0) == '[') {
			break;
		} else {
			jsonString = jsonString.replace(line, "");
			if (line.match(/.json$/i)) {
				$.ajax({
					url: line,
					dataType: 'json',
					async: false,
					success: function(data) {
						addWorkflowFromJson(data);
					}
				});			
			} else {
				var variable = line.split("=");
				if (variable != ''){
					var regex = new RegExp(variable[0], 'ig');
					//text = text.replace(regex, '<br />');
					//jsonString = jsonString.replace(variable[0], variable[1]);
					jsonString = jsonString.replace(regex, variable[1]);
				}
			}
		}		
	}
	var workflow = $.parseJSON( jsonString );
	addWorkflowFromJson(workflow);
	return false;
}

function loadXMLDoc(filename){
	if (window.ActiveXObject){
		xhttp = new ActiveXObject("Msxml2.XMLHTTP");
	} else {
		xhttp = new XMLHttpRequest();
	}
	xhttp.open("GET", filename, false);
	try {xhttp.responseType = "msxml-document"} catch(err) {} // Helping IE11
	xhttp.send("");
	return xhttp.responseXML;
}

function transformXml(xml) {
	xsl = loadXMLDoc("workflow.xsl");
	if (window.ActiveXObject || xhttp.responseType == "msxml-document"){
		html = xml.transformNode(xsl);
	}
	else if (document.implementation && document.implementation.createDocument){
		xsltProcessor = new XSLTProcessor();
		xsltProcessor.importStylesheet(xsl);
		html = xsltProcessor.transformToFragment(xml, document);
	}
	return html;
}

function renderResult(returnCode,executionTime,xml,status,detail){
	var output = '';
	if (returnCode=='4488'){output = '<font color="Green">PASS (4488) ' + executionTime + '</font>';}
	else {output = '<font color="red">FAIL (' + returnCode + ') ' + executionTime + '</font>';}
	status.html(output);
	
	var log = '<table width="100%" class="parameter"><tr><th>Result</th></tr><tr><td>';
	var result = transformXml(xml);
	log += result.querySelector('#result').innerHTML;
	log += '</td></tr></table>';
	detail.html(log);
}

function s4() {
	return Math.floor((1 + Math.random()) * 0x10000)
		.toString(16)
		.substring(1);
};

function guid() {
	return s4() + s4() + '-' + s4() + '-' + s4() + '-' +
		s4() + '-' + s4() + s4() + s4();
};

function parseValue(fieldValue, fieldName) {
	if (fieldValue != "") {
		$.each(globalVariable, function(key, value){ 
			if (typeof(value)=='string') {
				var regex = new RegExp(key, 'ig');
				fieldValue = fieldValue.replace(regex, value); 
			}
		});
		var squareText = fieldValue.match(/(\['[(\w)\-]*'\])+/ig);
		if (squareText) {
			$.each(squareText, function(i){
				var squareValue = eval("globalVariable" + squareText[i]);
				if (squareValue !== undefined) {
					fieldValue = fieldValue.replace(squareText[i], squareValue);
				}
			});
		}
	} else {
		if (globalVariable[fieldName]) {
			fieldValue = globalVariable[fieldName];
		}
	}
	return fieldValue
}

$(function() {

	$.ajaxSetup({
		type: 'GET',
		dataType: 'xml',
		timeout: 86400000
	});
	
	//$('#sortable').on("mouseenter mouseleave", "tr", function(){
	//	$(this).toggleClass("highlight");
	//});
	
	$('#sortable').on('click', '.btnGetDatastore', function() {	
		var button = $(this);
		var form = button.parents('form');
		var vcAddress = form.find('input[name="vcAddress"]');
		if (vcAddress.length > 0) {
			srvAddr = vcAddress.val();
			var vcUser = form.find('input[name="vcUser"]');
			if (vcUser.val() == "") {
				srvUser = "administrator";
			} else {
				srvUser = vcUser.val();
			}
			srvPwd = form.find('input[name="vcPassword"]').val();
		} else {
			srvAddr = form.find('input[name="serverAddress"]').val();
			srvUser = form.find('input[name="serverUser"]').val();
			srvPwd = form.find('input[name="serverPassword"]').val();
		}
		
		if (srvAddr == "") {
			alert("Please specify server address.");
			return false;
		}
		
		button.attr('disabled', true);
		button.attr('value', 'Loading...');

		$.ajax({
			type: "POST",
			url: "webcmd.php?command=listDatastore",
			data: {
				serverAddress: srvAddr,
				serverUser: srvUser,
				serverPassword: srvPwd
			},
			dataType: 'xml'
		})
		.success(function (xml) {
			returnCode = $(xml).find('returnCode').text();
			if (returnCode != "4488") {
				alert("Failed to list datastore, please check server address and credential.");
				return false;
			} else {
				var datalist = form.find('datalist[name="datastore"]');
				datalist.empty();
				$(xml).find('datastore').each(function(){
					ds = $(this).find('name').text();
					fs = $(this).find('freespace').text();
					if ( !ds.match(/[iso|flp]_images_/gi)) {
						datalist.append('<option value="' + ds + '">' + ds + ' (free space: ' + fs + 'GB)</option>');
					}
				});
			}
		})
		.fail(function(ret) {
			alert($('#').val());
			alert("Load Datasotre Error: " + ret);
		})
		.always(function() {
			button.attr('value', 'List Datastore');
			button.attr('disabled', false);
		});
    });
	
	$('#sortable').on('click', '.btnGetPortGroup', function() {	
		var button = $(this);
		var form = button.parents('form');
		var vcAddress = form.find('input[name="vcAddress"]');
		if (vcAddress.length > 0) {
			srvAddr = vcAddress.val();
			var vcUser = form.find('input[name="vcUser"]');
			if (vcUser.val() == "") {
				srvUser = "administrator";
			} else {
				srvUser = vcUser.val();
			}
			srvPwd = form.find('input[name="vcPassword"]').val();
		} else {
			srvAddr = form.find('input[name="serverAddress"]').val();
			srvUser = form.find('input[name="serverUser"]').val();
			srvPwd = form.find('input[name="serverPassword"]').val();
		}
		
		if (srvAddr == "") {
			alert("Please specify server address.");
			return false;
		}
		
		button.attr('disabled', true);
		button.attr('value', 'Loading...');

		$.ajax({
			type: "POST",
			url: "webcmd.php?command=listPortGroup",
			data: {
				serverAddress: srvAddr,
				serverUser: srvUser,
				serverPassword: srvPwd
			},
			dataType: 'xml'
		})
		.success(function (xml) {
			returnCode = $(xml).find('returnCode').text();
			if (returnCode != "4488") {
				alert("Failed to list port group, please check server address and credential.");
				return false;
			} else {
				var datalist = form.find('datalist[name="portGroup"]');
				datalist.empty();
				$(xml).find('portGroup').each(function(){
					pg = $(this).find('name').text();
					datalist.append('<option value="' + pg + '">' + pg + ' </option>');
				});
			}
		})
		.fail(function(ret) {
			alert($('#').val());
			alert("Load port group Error: " + ret);
		})
		.always(function() {
			button.attr('value', 'List Port Group');
			button.attr('disabled', false);
		});
    });
	
	$('#sortable').on('click', '.btnGetBuild', function() {	
		var button = $(this);
		var form = button.parents('form');
		var product = form.find('input[name="product"]').val();
		var branch = form.find('input[name="branch"]').val();
		
		if (product == "" || branch == "") {
			alert("Please specify product and branch.");
			return false;
		}
		
		button.attr('disabled', true);
		button.attr('value', 'Searching...');

		$.ajax({
			type: "POST",
			url: "webcmd.php?command=listBuild",
			data: {
				branch: branch,
				product: product
			},
			dataType: 'xml'
		})
		.success(function (xml) {
			returnCode = $(xml).find('returnCode').text();
			if (returnCode != "4488") {
				alert("Failed to list build, please check product and branch.");
				return false;
			} else {
				var datalist = form.find('datalist[name="build"]');
				datalist.empty();
				$(xml).find('build').each(function(){
					bt = $(this).find('buildtype').text();
					rt = $(this).find('releasetype').text();
					cs = $(this).find('changeset').text();
					id = $(this).find('id').text();
					datalist.append('<option value="' + id + '">' + id + ' (changeset: ' + cs + ' | release type: ' + rt + ' | build type: ' + bt + ')</option>');		
				});
			}
		})
		.fail(function(ret) {
			alert($('#').val());
			alert("Search Build Error: " + ret);
		})
		.always(function() {
			button.attr('value', 'List Build');
			button.attr('disabled', false);
		});
    });
	
	$('#sortable').on('click', '.btnGetMoreIso', function() {	
		var button = $(this);
		var form = button.parents('form');
		var isoPath = form.find('select[name="isoPath"]');
		button.attr('disabled', true);
		$.ajax({
			type: "GET",
			url: "isoList.txt",
			dataType: 'text'
		})
		.success(function (isoList) {
			lines = isoList.split(/\r?\n/g);
			for (line in lines){
				path = lines[line].split("/");
				name = path[path.length-1];
				isoPath.append('<option value="' + lines[line] + '">' + name + '</option>');
			}
		})
		.fail(function(ret) {
			alert($('#').val());
			alert("Get ISO path error: " + ret);
		})
		.always(function() {
			button.attr('disabled', true);
		});
    });
	
	$('#sortable').on('change', 'textarea[name*="wf_des"]', function() {	
		var des = $(this).parents('div.command').find('span.description');
		var text = $(this).val().split('\n')[0];
		des.html(text);
    });
	
	$('#onOffAll').click(function(){ 
		$('#onOffAll').toggleClass('offAll');
		//if ($('#onOffAll').attr('class') == 'execute offAll') 
		if ($('#onOffAll').hasClass('offAll')){
			$('form').addClass('off');
			$('.onoff').prop('src','images/button-off-icon.png');
			$('#onOffAll').prop('src','images/button-off-all-icon.png');
		} else {
			$('form').removeClass('off');
			$('.onoff').prop('src','images/button-on-icon.png');
			$('#onOffAll').prop('src','images/button-on-all-icon.png');
		}
	});	
	
	$('#toggleAll').click(function(){ 
		$('#toggleAll').toggleClass('offAll'); 
		if ($('#toggleAll').hasClass('offAll')){
			$('div.body').slideUp(500);
		} else {
			$('div.body').slideDown(500);
		}
	});	

	$('#serial').click(function(){
		globalVariable={};
		$(document).clearQueue("ajaxRequests");
		var itrNumber = $('#iteration').val();
		if (itrNumber.indexOf(" of ") >= 0) {
			currentItr = parseInt(itrNumber.split(" of ")[0]) + 1;
			totalItr = itrNumber.split(" of ")[1];
		} else {
			currentItr = 1;
			totalItr = parseInt(itrNumber) ? itrNumber : 1;
		}
		$('#iteration').val(currentItr + " of " + totalItr);
		$('form').not('.off').each(function(){
			var form = $(this);
			var status = form.parents('div.command').find('.status');
			var detail = form.parents('div.command').find('.detail');
			status.empty();
			detail.empty();
			$(document).queue("ajaxRequests", function(){
				if (form.hasClass('off')) {
					//status.html('<font color="Gray">Skipped</font>');
					$(document).dequeue("ajaxRequests");
					return;
				};
				var start = $.now();
				status.html('<font color="Gold">Running...</font>');
				if (form.attr('name')=='sleep'){
					var second = form.find('input[name="second"]').val();
					second = parseValue(second,"second");
					setTimeout(function(){
						var executionTime = second + " seconds";
						var xml = '<webcommander><result><customizedOutput>Info - sleep ' + second + ' seconds</customizedOutput></result></webcommander>';
						xml = $.parseXML(xml);
						renderResult('4488',executionTime,xml,status,detail);
						if ($('#autoDisable').is(':checked')) {form.parents('div.command').find('.onoff').trigger('click');}
						$(document).dequeue("ajaxRequests");
					}, second * 1000);
				} else if (form.attr('name')=='defineVariable'){
					var kvList = form.find('textarea[name="variableList"]').val();
					var lines = kvList.split("\n");
					for (var i in lines) {
						line = lines[i];	
						var variable = line.split(/=(.+)?/);
						if (variable != ''){
							var vname = variable[0].trim();
							if (variable[1] !== undefined) {
								var vvalue = variable[1].trim();
							} else {
								alert('Variable "' + vname + '" is not defined!');
								status.html("");
								return false;
							}
							vvalue = parseValue(vvalue,vname);
							globalVariable[vname]=vvalue; 
						}			
					}
					setTimeout(function(){
						var executionTime = "1 second";
						var xml = '<webcommander><result><stdOutput>' + JSON.stringify(globalVariable, null, "\t") + '</stdOutput></result></webcommander>';
						xml = $.parseXML(xml);
						renderResult('4488',executionTime,xml,status,detail);
						$(document).dequeue("ajaxRequests");
					}, 1000);
				} else {
					var formData = new FormData();
					$.each(form[0], function(){
						var fieldName = $(this).attr('name');
						if ($(this).attr('type') != 'file') {
							var fieldValue = $(this).val();
							fieldValue = parseValue(fieldValue,fieldName);
							formData.append(fieldName,fieldValue);
						} else {
							var fileToUpload = $(this)[0].files[0];
							if (fileToUpload) {
								formData.append(fieldName,fileToUpload);
							}
						}
					});
					$.ajax({
						url: 'webcmd.php?command=' + form.attr('name'),
						type: 'POST',
						data: formData,
						async: true,
						cache: false,
						contentType: false,
						processData: false
					})
					.success(function(xml){
						var returnCode = $(xml).find('returnCode').text();
						//var executionTime = $(xml).find('executiontime').text();
						var executionTime = ($.now() - start) / 1000 + " seconds";
						renderResult(returnCode,executionTime,xml,status,detail);
						if (returnCode=='4488'){
							var kvList = form.find('textarea[name="variableList"]').val();
							var lines = kvList.split("\n");
							for (var i in lines) {
								line = lines[i];	
								var variable = line.split(/=(.+)?/);
								if (variable != ''){
									var vname = variable[0].trim();
									if (vname.match('JSON$')) {
										var vvalue = $.parseJSON($(xml).xpath(variable[1]).text());
									} else {
										var vvalue = $(xml).xpath(variable[1]).text();
									}	
									globalVariable[vname]=vvalue;
								}			
							}						
							if ($('#autoDisable').is(':checked')) {form.parents('div.command').find('.onoff').trigger('click');}
							$(document).dequeue("ajaxRequests");
						}
						else {return false;}
					});
				}
			});
		});
		$(document).queue("ajaxRequests", function() {
			if (currentItr < totalItr) {$('#serial').trigger("click");}
		});
		$(document).dequeue("ajaxRequests");
	});
	
	$('#parallel').click(function(){
		$('form').not('.off').each(function(){
			var form = $(this);
			var status = form.parents('div.command').find('.status');
			var detail = form.parents('div.command').find('.detail');
			detail.empty();
			var start = $.now();
			status.html('<font color="Gold">Running...</font>');
			if (form.attr('name')=='sleep'){
				var second = form.find('input[name="second"]').val();
				setTimeout(function(){
					var executionTime = second + " seconds";
					var xml = '<webcommander><result><customizedOutput>Info - sleep ' + second + ' seconds</customizedOutput></result></webcommander>';
					xml = $.parseXML(xml);
					renderResult('4488',executionTime,xml,status,detail);
				}, second * 1000);
			} else {
				var formData = new FormData(form[0]);
				$.ajax({
					url: 'webcmd.php?command=' + form.attr('name'),
					type: 'POST',
					data: formData,
					async: true,
					cache: false,
					contentType: false,
					processData: false
				})
				.success(function(xml){
					var returnCode = $(xml).find('returnCode').text();
					//var executionTime = $(xml).find('executiontime').text();
					var executionTime = ($.now() - start) / 1000 + " seconds";
					renderResult(returnCode,executionTime,xml,status,detail);
				});
			}
		});
	});
	
	$('#import').click(function(){
		$("#dialogImport").remove();
		var dialog = '<div id="dialogImport" title="Import workflow from JSON"><center><textarea id="jsonImport" class="json">';
		dialog += '</textarea></center></div>';
		$('#sortable').after(dialog);
		$( "#dialogImport" ).dialog({
			width:600,
			modal:true,
			buttons: {
				"Add workflow": function(){
					var workflow = $('#jsonImport').val();
					addWorkflow(workflow);
					return false;
				}
			}
		});
	});
	
	$('#export').click(function(){
		$("#dialogExport").remove();
		var dialog = '<div id="dialogExport" title="Export workflow to JSON"><center><textarea id="jsonExport" class="json">[';
		var workflow = '';
		$('form').each(function(){
			var wj = $(this).serializeObject();
			if ($(this).is('.off')) {
				wj['wf_off'] = '1';
			}
			workflow += JSON.stringify(wj, null, '\t');
			workflow += ',\n';
		});	
		dialog += workflow.slice(0, -2);
		dialog += ']</textarea></center></div>';
		$('#sortable').after(dialog);
		$( "#dialogExport" ).dialog({width:600});
	});
	
	$.get('webcmd.php',function(webcmd){
		$("#sortable").sortable({
			update: function() {
				updateOrder();
			}
		});
		//$(".content").hide();
		$("#sortable").on('click', '.toggle', function(){
			$(this).parents('p').next('div.body:first').slideToggle(500);
		});

		select_cmd = '<select class="cmdlist"><option selected disabled>Select a command to run</option>';
		var cmd_list = $(webcmd)
			.find('webcommander')
			.append('<command name="sleep" synopsis="Sleep">\
						<parameters>\
							<parameter name="second" helpmessage="number of second to sleep" />\
						</parameters>\
						<functionalities>\
							<functionality>Workflow</functionality>\
						</functionalities>\
					</command>\
					<command name="defineVariable" synopsis="Define variables">\
						<parameters>\
							<parameter name="variableList" helpmessage="Define variables in key=value pairs, one definition per line" type="textarea" />\
						</parameters>\
						<functionalities>\
							<functionality>Workflow</functionality>\
						</functionalities>\
					</command>')
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
		$('.description').before(select_cmd);
		
		$("#sortable").on('click', '.status', function(){ 
			var content = $(this).parents('div.command').find('.content');
			var detail = $(this).parents('div.command').find('.detail');

			if (content.is( ':visible' )){
				content.hide('fast');
				detail.show('slow');
			} else {
				detail.hide('fast');
				content.show('slow');	
			};
		});
		
		$("#sortable").on('click', '.add', function(){ 
			var currentCommand = $(this).parents('div:first');
			addCommand(currentCommand);
			updateOrder();
		});
			
		$("#sortable").on('click', '.delete', function(){ 
			//$(this).parents("div:first").remove();
			var cmd = $(this).parents("div.command:first");
			cmd.hide('slow', function(){ 
				cmd.remove(); 
				updateOrder();
			});
		});	

		$("#sortable").on('click', '.onoff', function(){ 
			var cmdform = $(this).parents("div:first").find('form');
			cmdform.toggleClass('off');
			if (cmdform.attr('class') == 'off') {
				//cmdform.find('input').prop('disabled',true);
				//cmdform.find('select').prop('disabled',true);
				///cmdform.find('textarea').prop('disabled',true);
				$(this).prop('src','images/button-off-icon.png');
			} else {
				//cmdform.find('input').prop('disabled',false);
				//cmdform.find('select').prop('disabled',false);
				//cmdform.find('textarea').prop('disabled',false);
				$(this).prop('src','images/button-on-icon.png');
			}
		});	
		
		$("#sortable").on('change', '.cmdlist', function(){ 
			$(this).parents("div.command").find(".content:first").empty();
			var status = $(this).parents('div.command').find('.status, .description');
			status.empty();
			var cmd = $(this).val();
			var xml = $(webcmd).find('command').filter(function() {
                return $(this).attr('name') == cmd;
            });
			var table = '<form name="'; 
			table += cmd; 
			table += '"><table width="100%" class="parameter"><tr class="header"><th width="20%">Name</th><th width="30%">Value</th><th width="50%">Help Message</th></tr>';
			$(xml).find('parameter').each(function(){
				var param = $(this);
				var name = param.attr('name');
				table += '<tr><td>' + name;
				if (param.attr('mandatory') == '1'){table += ' *';}
				table += '</td><td>';
				var type = param.attr('type');
				switch (type){
					case 'textarea':
						table += '<textarea type="textarea" name="' + name + '"></textarea>';
						break;
					case 'file':
						table += '<input type="file" size="60" name="' + name + '"></input>';
						break;
					case 'password':
						table += '<input type="password" size="40" name="' + name + '"></input>';
						break;
					case 'option':
						table += '<select type="select" name="' + name + '">';
						param.find('option').each(function(){
							table += '<option value="' + $(this).attr('value') + '">' + $(this).text() + '</option>';
						});
						table += '</select>';
						break;
					case 'selectText':
						var aguid = guid();
						table += '<input type="text" size="40" placeholder="Double click or enter keyword here" name="' + name + '" list="' + aguid + '"></input>';
						table += '<datalist id="' + aguid + '" name="' + name + '">';
						param.find('option').each(function(){
							table += '<option value="' + $(this).attr('value') + '">' + $(this).text() + '</option>';
						});
						table += '</datalist>';
						break;
					default:
						table += '<input type="text" size="40" name="' + name + '"></input>';
				};
				switch (name){
					case 'datastore':
						table += '<input type="button" class="btnGetDatastore" value="List Datastore" />';
						break;
					case 'portGroup':
						table += '<input type="button" class="btnGetPortGroup" value="List Port Group" />';
						break;
					case 'build':
						table += '<input type="button" class="btnGetBuild" value="List Build" />';
						break;
					case 'isoPath':
						table += '<input type="button" class="btnGetMoreIso" value="Get more ISO" />';
					default:
						break;
				};
				table += '</td><td>'  + param.attr('helpmessage') + '</td></tr>';
			});
			if (0 > $.inArray(xml.attr('name'),['sleep','defineVariable'])) {
				table += '<tr class="wf"><td>variableList</td><td>';
				table += '<textarea type="textarea" name="variableList" placeholder="Define variables based on command output"></textarea></td>';
				table += '<td>Define variables in key=XPath_expression pairs, one definition per line.<br/>\
							The XPath_expression is used to get the text of an XML element from this command output. </td></tr>';
			}
			table += '<tr class="wf"><td>Command description</td><td>';
			table += '<textarea type="textarea" name="wf_des"></textarea></td>';
			table += '<td>Write down a desciption here so that you will not forget what it does</td></tr>';
			table += '</table></form>';
			var $table = $(table);
			var content = $(this).parents("div.command").find(".content");
			var detail = $(this).parents("div.command").find(".detail");
			//content.append(table);
			$table.appendTo(content);
			content.show();
			detail.hide();
			//content.find("tr:even").addClass("stripe1");
			//content.find("tr:odd").addClass("stripe2");
			$table.hide().show('slow');
			//return false;
		});
		
		var template = document.location.search.substr(1);
		if ( template !== "") {
			$.ajax({
				url: template,
				dataType: 'json',
				async: false,
				success: function(data) {
					$("div.command").remove();
					addWorkflowFromJson(data);
				}
			});			
		}
	});		
});