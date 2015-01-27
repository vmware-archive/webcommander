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
	o["command"] = this.attr('action').replace("webcmd.php?command=", "");;
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

$(document).ready(function() {
	
	$('.catchk').change(function() {
		var filter = [];
		$("input.catchk:checked").each(function(index) {
			filter.push("." + $(this).attr('name'));
		});
		if (filter.length == 0) {
			$("ol > li").show();
		} else {
			$("ol > li").hide();
			$("ol > li").filter(filter.join(', ')).show();
		}
    });
	
    $('#btnGetDatastore').click(function() {	
		if ($('#vcAddress').length > 0) {
			srvAddr = $('#vcAddress').val();
			if ($('#vcUser').val() == "") {
				srvUser = "administrator";
			} else {
				srvUser = $('#vcUser').val();
			}
			srvPwd = $('#vcPassword').val();
		} else {
			srvAddr = $('#serverAddress').val();
			srvUser = $('#serverUser').val();
			srvPwd = $('#serverPassword').val();
		}
		
		if (srvAddr == "") {
			alert("Please specify server address.");
			return false;
		}
		
		$('#btnGetDatastore').attr('disabled', true);
		$('#btnGetDatastore').attr('value', 'Loading...');

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
				$('#datastore').children().remove();
				$('#datastore').append('<datalist id="datastore">');
				$(xml).find('datastore').each(function(){
					ds = $(this).find('name').text();
					fs = $(this).find('freespace').text();
					if ( 
						!ds.match(/[iso|flp]_images_/gi)
						// ds != '' &&
						// ds != 'iso_images_bj' &&
						// ds != 'iso_images_pa' &&
						// ds != 'iso_images_bl' &&
						// ds != 'iso_images_sg' &&
						// ds != 'flp_images_bj' &&
						// ds != 'flp_images_wdc'
					) {
						$('#datastore').append('<option value="' + ds + '">' + ds + ' (free space: ' + fs + 'GB)</option>');
					}
				});
				$('#datastore').append('</datalist>');
			}
		})
		.fail(function(ret) {
			alert($('#').val());
			alert("Load Datasotre Error: " + ret);
		})
		.always(function() {
			$('#btnGetDatastore').attr('value', 'List Datastore');
			$('#btnGetDatastore').attr('disabled', false);
		});
    });
	
	$('#btnGetPortGroup1').click(function() {	
		if ($('#vcAddress').length > 0) {
			srvAddr = $('#vcAddress').val();
			if ($('#vcUser').val() == "") {
				srvUser = "administrator";
			} else {
				srvUser = $('#vcUser').val();
			}
			srvPwd = $('#vcPassword').val();
		} else {
			srvAddr = $('#serverAddress').val();
			srvUser = $('#serverUser').val();
			srvPwd = $('#serverPassword').val();
		}
		
		if (srvAddr == "") {
			alert("Please specify server address.");
			return false;
		}
		
		$('#btnGetPortGroup').attr('disabled', true);
		$('#btnGetPortGroup').attr('value', 'Loading...');

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
				$('#portGroup').children().remove();
				$('#portGroup').append('<datalist id="portGroup">');
				$(xml).find('portGroup').each(function(){
					pg = $(this).find('name').text();
					$('#portGroup').append('<option value="' + pg + '">' + pg + ' </option>');
				});
				$('#portGroup').append('</datalist>');
			}
		})
		.fail(function(ret) {
			alert($('#').val());
			alert("Load port group Error: " + ret);
		})
		.always(function() {
			$('#btnGetPortGroup').attr('value', 'List Port Group');
			$('#btnGetPortGroup').attr('disabled', false);
		});
    });
	
	$('#btnGetPortGroup').click(function() {	
		if ($('#vcAddress').length > 0) {
			srvAddr = $('#vcAddress').val();
			if ($('#vcUser').val() == "") {
				srvUser = "administrator";
			} else {
				srvUser = $('#vcUser').val();
			}
			srvPwd = $('#vcPassword').val();
		} else {
			srvAddr = $('#serverAddress').val();
			srvUser = $('#serverUser').val();
			srvPwd = $('#serverPassword').val();
		}
		
		if (srvAddr == "") {
			alert("Please specify server address.");
			return false;
		}
		
		$('#btnGetPortGroup').attr('disabled', true);
		$('#btnGetPortGroup').attr('value', 'Loading...');

		$.ajax({
			type: "POST",
			url: "webcmd.php?command=listPortGroup&format=JSON",
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
				$('#portGroup').children().remove();
				$('#portGroup').append('<datalist id="portGroup">');
				var jsonString = $(xml).find('stdOutput').text();
				var portGroup = $.parseJSON( jsonString );
				portGroup.forEach(function(pg){
					$('#portGroup').append('<option value="' + pg.Name + '">' + pg.Name + '</option>');
				});
				
				$('#portGroup').append('</datalist>');
			}
		})
		.fail(function(ret) {
			alert($('#').val());
			alert("Load port group Error: " + ret);
		})
		.always(function() {
			$('#btnGetPortGroup').attr('value', 'List Port Group');
			$('#btnGetPortGroup').attr('disabled', false);
		});
    });
	
	$('#btnGetBuild').click(function() {	
		
		product = $('#product').val();
		branch = $('#branch').val();
		
		if (product == "" || branch == "") {
			alert("Please specify product and branch.");
			return false;
		}
		
		$('#btnGetBuild').attr('disabled', true);
		$('#btnGetBuild').attr('value', 'Searching...');

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
				$('#build').children().remove();
				$('#build').append('<datalist id="build">');
				$(xml).find('build').each(function(){
					bt = $(this).find('buildtype').text();
					rt = $(this).find('releasetype').text();
					cs = $(this).find('changeset').text();
					id = $(this).find('id').text();
					$('#build').append('<option value="' + id + '">' + id + ' (changeset: ' + cs + ' | release type: ' + rt + ' | build type: ' + bt + ')</option>');		
				});
				$('#build').append('</datalist>');
			}
		})
		.fail(function(ret) {
			alert($('#').val());
			alert("Search Build Error: " + ret);
		})
		.always(function() {
			$('#btnGetBuild').attr('value', 'List Build');
			$('#btnGetBuild').attr('disabled', false);
		});
    });
	
	$('#btnGetMoreIso').click(function() {
		$('#btnGetMoreIso').attr('disabled', true);
		$.ajax({
			type: "GET",
			url: "isoList.txt",
			dataType: 'text'
		})
		.success(function (isoList) {
			lines = isoList.split(/\r?\n/g);
			for (line in lines){
				isoPath = lines[line].split("/");
				isoName = isoPath[isoPath.length-1];
				$('#isoPath').append('<option value="' + lines[line] + '">' + isoName + '</option>');
			}
		})
		.fail(function(ret) {
			alert($('#').val());
			alert("Get ISO path error: " + ret);
		})
		.always(function() {
			$('#btnGetMoreIso').attr('disabled', true);
		});
    });
	
	/*if ($('#isoPath').length > 0) {
		$.ajax({
			type: "GET",
			url: "isoList.txt",
			dataType: 'text'
		})
		.success(function (isoList) {
			lines = isoList.split(/\r?\n/g);
			for (line in lines){
				isoPath = lines[line].split("/");
				isoName = isoPath[isoPath.length-1];
				$('#isoPath').append('<option value="' + lines[line] + '">' + isoName + '</option>');
			}
		})
	}*/
	
	$('#btnSubmit').click(function() {	
		$('#btnSubmit').attr('disabled', true);
		$('#btnSubmit').attr('value', 'Running');
		$('#imgWait').css({"visibility":"visible"});
		$('#returnCode').css({"visibility":"hidden"});
		$('#result').html('<center><h3>webCommander is handling your request. Please wait.</h3></center>');
		$('#form1').submit();
    });
	
	$('#btnJson').click(function() {	
		$("#dialogExport").remove();
		var dialog = '<div id="dialogExport" title="Export command to JSON"><center><textarea style="width:760px;height:500px" id="jsonExport" class="json">[';
		var workflow = '';
		$('form').each(function(){
			workflow += JSON.stringify($(this).serializeObject(), null, '\t');
			workflow += ',\n';
		});	
		dialog += workflow.slice(0, -2);
		dialog += ']</textarea></center></div>';
		$('#btnJson').after(dialog);
		$( "#dialogExport" ).dialog({width:800});
    });
	
	$('#btnUrl').click(function() {	
		$("#dialogExport").remove();
		var dialog = '<div id="dialogExport" title="Export command to URL"><center><textarea style="width:760px;height:300px" id="jsonExport" class="json">';
		dialog += window.location.protocol + "//" + window.location.host + "/" + $('form').attr("action") + "&";
		dialog += $('form').serialize();
		dialog += '</textarea></center></div>';
		$('#btnUrl').after(dialog);
		$( "#dialogExport" ).dialog({width:800});
    });
});
/*
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
*/

if (window.FormData === undefined) {
	alert("Please use an HTML 5 compatible browser, such as Firefox 21, Chrome 27, Opera 12 and IE 10.");
	window.location="http://www.firefox.com";
}