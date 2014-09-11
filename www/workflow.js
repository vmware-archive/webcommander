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
	var $cmd = $('<div class="command"><p class="heading">\
		' + select_cmd + '<span class="status"></span><span class="right"> \
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
}

function addWorkflow(jsonString){
	var lines = jsonString.split("\n");
	for (var i in lines) {
		line = lines[i];
		if (line.charAt(0) == '[') {
			break;
		} else {
			jsonString = jsonString.replace(line, "");
			var variable = line.split("=");
			if (variable != ''){
				var regex = new RegExp(variable[0], 'g');
				//text = text.replace(regex, '<br />');
				//jsonString = jsonString.replace(variable[0], variable[1]);
				jsonString = jsonString.replace(regex, variable[1]);
			}
		}		
	}
	var workflow = $.parseJSON( jsonString );
	workflow.forEach(function(command){
		var currentCommand = $('div.command:last');
		addCommand(currentCommand);
		$('div.command:last')
			.find('.cmdlist')
			.find('option[value="' + command.command + '"]')
			.prop('selected',true)
			.change();	
		var form = $('div.command:last').find('form:first');
		populate(form,command);
	});
	return false;
}

function renderResult(returnCode,executionTime,xml,status,detail){
	var output = '';
	if (returnCode=='4488'){output = '<font color="Green">PASS (4488) ' + executionTime + '</font>';}
	else {output = '<font color="red">FAIL (' + returnCode + ') ' + executionTime + '</font>';}
	status.html(output);
	
	var log = '<table width="100%" class="parameter"><tr><th>Result</th></tr><tr><td>';
	
	var co = $(xml).find('customizedOutput');
	if (co.length != 0) {
		log += '<ul>';
		co.each(function() {
			log += '<li>' + $(this).text() + '</li>';
		});
		log += '</ul>';
	}
	
	var err = $(xml).find('stderr');
	if (err.length != 0) {
		log += '<center>';
		log += '<table class="exceptionTable">';
		log += '<tr><th colspan="2">Exception occurred</th></tr>';
		log += '<tr><td>Exception Type</td><td>' + err.find('exceptionType').text() + '</td></tr>';
		log += '<tr><td>Fully Qualified Error ID</td><td>' + err.find('fullyQualifiedErrorId').text() + '</td></tr>';
		log += '<tr><td>Error Message</td><td>' + err.find('errMessage').text() + '</td></tr>';
		log += '<tr><td>Script Name</td><td>' + err.find('scriptName').text() + '</td></tr>';
		log += '<tr><td>Scripte Line Number</td><td>' + err.find('scriptLineNumber').text() + '</td></tr>';
		log += '</table>';
		log += '</center>';
	}
	
	var so = $(xml).find('stdOutput');
	if (so.length != 0) {
		log += '<ul>';
		so.each(function() {
			log += '<pre>' + $(this).text() + '</pre>';
		});
		log += '</ul>';
	}
	
	var app = $(xml).find('Property[Name="name"]');
	if (app.length != 0) {
		log += '<center>';
		log += '<table class="exceptionTable">';
		log += '<tr><th>Application</th><th>Vendor</th><th>Version</th></tr>';
		app.each(function() {
			log += '<tr><td>' + $(this).text() + '</td>';
			log += '<td>' + $(this).siblings('Property[Name="vendor"]').text() + '</td>';
			log += '<td>' + $(this).siblings('Property[Name="version"]').text() + '</td></tr>';
		})
		log += '</table>';
		log += '</center>';
	}
	
	var vmhost = $(xml).find('VmHost');
	if (vmhost.length != 0) {
		vmhost.each(function() {
			var host = $(this);
			log += '<center>';
			log += '<table class="exceptionTable" width="50%">';
			log += '<tr><th width="20%">Property</th><th width="80%">Value</th></tr>';
			host.find('Property').each(function(){
				log += '<tr><td>' + $(this).attr("Name") + '</td>';
				log += '<td>' + $(this).text() + '</td></tr>';
			});
			log += "</table></center>";
		});
	}
	
	var vm = $(xml).find('vm');
	if (vm.length != 0) {
		log += '<center><table class="exceptionTable">';
		log += '<tr><th>VM</th><th>Remote control via VMRC ( download <a href="download/vmrc.zip">here</a> )</th><th>Remote control via MSTSC</th></tr>';
		vm.each(function() {			
			log += '<tr><td>' + $(this).find("name").text() + '</td>';
			log += '<td>c:\\vmrc\\vmware-vmrc.exe -h ' + $(this).find("hostaddr").text() + ' -d "' + $(this).find("vmdkpath").text() + '" -u root -p ' + $(this).find("hostpassword").text() + '</td>';
			log += '<td>mstsc /v:' + $(this).find("ip").text() + '</td></tr>';
		});
		log += '</table></center>';	
	}
	
	var rp = $(xml).find('resourcepool');
	if (rp.length != 0) {
		log += '<center><table class="exceptionTable" width="60%">';
		log += '<tr><th>Name</th><th>ID</th><th>Path</th></tr>';
		rp.each(function() {			
			log += '<tr><td>' + $(this).find("name").text() + '</td>';
			log += '<td>' + $(this).find("id").text() + '</td>';
			log += '<td>' + $(this).find("path").text() + '</td></tr>';
		});
		log += '</table></center>';	
	}
	
	var desktop = $(xml).find('desktop');
	if (desktop.length != 0) {
		log += '<center><table class="exceptionTable" width="60%">';
		log += '<tr><th>Pool ID</th><th>Desktop Name</th><th>Assigned User (for dedicated pool)</th><th>State</th></tr>';
		desktop.each(function() {			
			log += '<tr><td>' + $(this).find("poolid").text() + '</td>';
			log += '<td>' + $(this).find("desktopname").text() + '</td>';
			log += '<td>' + $(this).find("assigneduser").text() + '</td>';
			log += '<td>' + $(this).find("state").text() + '</td></tr>';
		});
		log += '</table></center>';	
	}
	
	var vm = $(xml).find('virtualmachine');
	if (vm.length != 0) {
		log += '<center><table class="exceptionTable" width="60%">';
		log += '<tr><th>VM Name</th><th>IP</th><th>Snapshots</th></tr>';
		vm.each(function() {
			var vm = $(this);
			log += '<tr><td>' + vm.find("name").text() + '</td>';
			log += '<td>' + vm.find("ip").text() + '</td>';
			log += '<td>';
			vm.find('snapshot').each(function() {
				log += $(this).text() + " | ";
			})
			log += '</td></tr>';
		});
		log += '</table></center>';	
	}
	
	var pg = $(xml).find('portGroup');
	if (pg.length != 0) {
		log += '<center><table class="exceptionTable" width="60%">';
		log += '<tr><th>Name</th><th>VLAN ID</th><th>Virtual Switch</th></tr>';
		pg.each(function() {
			log += '<tr><td>' + $(this).find("name").text() + '</td>';
			log += '<td>' + $(this).find("vlanId").text() + '</td>';
			log += '<td>' + $(this).find("virtualSwtichName").text() + '</td></tr>';
		});
		log += '</table></center>';	
	}
	
	var build = $(xml).find('build');
	if (build.length != 0) {
		log += '<center><table class="exceptionTable">';
		log += '<tr><th>ID</th><th>Changeset</th><th>Release Type</th><th>Build Type</th><th>Start Time</th><th>End Time</th><th>BAT Result</th></tr>';
		build.each(function() {
			log += '<tr><td>' + $(this).find("id").text() + '</td>';
			log += '<td>' + $(this).find("changeset").text() + '</td>';
			log += '<td>' + $(this).find("releasetype").text() + '</td>';
			log += '<td>' + $(this).find("buildtype").text() + '</td>';
			log += '<td>' + $(this).find("starttime").text() + '</td>';
			log += '<td>' + $(this).find("endtime").text() + '</td>';
			log += '<td>' + $(this).find("qaresult").text() + '</td></tr>';
		});
		log += '</table></center>';	
	}
	
	var ds = $(xml).find('datastore');
	if (ds.length != 0) {
		log += '<center><table class="exceptionTable" width="60%">';
		log += '<tr><th>Name</th><th>Free Space GB</th><th>Capacity GB</th></tr>';
		ds.each(function() {
			log += '<tr><td>' + $(this).find("name").text() + '</td>';
			log += '<td>' + $(this).find("freespace").text() + '</td>';
			log += '<td>' + $(this).find("capacity").text() + '</td></tr>';
		});
		log += '</table></center>';	
	}
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
		$(document).clearQueue("ajaxRequests");
		$('form').not('.off').each(function(){
			var form = $(this);
			var status = form.parents('div.command').find('.status');
			var detail = form.parents('div.command').find('.detail');
			status.empty();
			detail.empty();
			var key = form.find('input[name="wf_key"]').val();
			var tag = form.find('input[name="wf_tag"]').val();
	
			$(document).queue("ajaxRequests", function(){
				form.find('input[name!="wf_key"]').each(function(){
					var input = $(this);
					if (typeof window["wf_" + input.val()] != "undefined"){
						input.val(window["wf_" + input.val()]);
					}
				});
				if (form.hasClass('off')) {
					//status.html('<font color="Gray">Skipped</font>');
					$(document).dequeue("ajaxRequests");
					return;
				};
				var start = $.now();
				status.html('<font color="Gold">Running...</font>');
				$.ajax({
					url: 'webcmd.php?command=' + form.attr('name'),
					data: form.serialize()
				})
				.success(function(xml){
					var returnCode = $(xml).find('returnCode').text();
					//var executionTime = $(xml).find('executiontime').text();
					var executionTime = ($.now() - start) / 1000 + " seconds";
					renderResult(returnCode,executionTime,xml,status,detail);
					if (returnCode=='4488'){
						if (key && tag) {
							var value = $(xml).find(tag).text();
							eval("wf_" + key + " = '" + value + "'");
						}
						$(document).dequeue("ajaxRequests");
					}
					else {return false;}
				});
			});
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
			$.ajax({
				url: 'webcmd.php?command=' + form.attr('name'),
				data: form.serialize()
			})
			.success(function(xml){
				var returnCode = $(xml).find('returnCode').text();
				//var executionTime = $(xml).find('executiontime').text();
				var executionTime = ($.now() - start) / 1000 + " seconds";
				renderResult(returnCode,executionTime,xml,status,detail);
			});
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
			workflow += JSON.stringify($(this).serializeObject(), null, '\t');
			workflow += ',\n';
		});	
		dialog += workflow.slice(0, -2);
		dialog += ']</textarea></center></div>';
		$('#sortable').after(dialog);
		$( "#dialogExport" ).dialog({width:600});
	});
	
	$.get('webcmd.php',function(webcmd){
		$( "#sortable" ).sortable();
		//$(".content").hide();
		$("#sortable").on('click', '.toggle', function(){
			$(this).parents('p').next('div.body:first').slideToggle(500);
		});

		select_cmd = '<select class="cmdlist"><option selected disabled>Select a command to run</option>';
		var cmd_list = $(webcmd).find('command[hidden!="1"]');
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
		$('.status').before(select_cmd);
		
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
		});
			
		$("#sortable").on('click', '.delete', function(){ 
			//$(this).parents("div:first").remove();
			var cmd = $(this).parents("div:first");
			cmd.hide('slow', function(){ cmd.remove(); });
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
			var status = $(this).parents('div.command').find('.status');
			status.empty();
			var cmd = $(this).val();
			var xml = $(webcmd).find('command').filter(function() {
                return $(this).attr('name') == cmd;
            });
			var table = '<form name="'; 
			table += cmd; 
			table += '"><table width="100%" class="parameter"><tr><th width="20%">Name</th><th width="30%">Value</th><th width="50%">Help Message</th></tr>';
			$(xml).find('parameter').each(function(){
				var param = $(this);
				var name = param.attr('name');
				table += '<tr><td>' + name;
				if (param.attr('mandatory') == '1'){table += ' *';}
				table += '</td><td>';
				var type = param.attr('type');
				switch (type){
					case 'textarea':
						table += '<textarea type="textarea" cols="80" rows="20" name="' + name + '"></textarea>';
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
			table += '<tr><td>Define workflow variable</td><td>';
			table += '<input type="text" size="20" name="wf_key" placeholder="variable name"></input> = ';
			table += '<input type="text" size="20" name="wf_tag" placeholder="xml tag from the result"></input></td>';
			table += '<td>Define a variable with the command output to be used by other commands in the workflow</td></tr>';
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
	});		
});