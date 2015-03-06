/* **********************************************************
 * Copyright (C) 2013 VMware, Inc.
 * All Rights Reserved
 * **********************************************************/

 
// Globals
var mimetype = "application/x-vmware-remote-console-2012";
var clsid = "CLSID:4AEA1010-0A0C-405E-9B74-767FC8A998CB";

var isIE = /MSIE (\d+\.\d+);/.test(navigator.userAgent);
var vmrc = null;

// Constants
var VMRC_CS_CONNECTED;
var VMRC_MESSAGE_ERROR;
var VMRC_MKS;
var VMRC_EVENT_MESSAGES;

// Helper functions to simply looking up document elements and their values.
function $(id) {
	return document.getElementById(id);
}

function $V(id) {
	return $(id).value;
}

// Helper functions for logging messages
function log(text) {
	var timestamp = (new Date()).toUTCString();
	$('msgBox').innerHTML += "<br />" + '[' + timestamp + '] ' + text;
	$('msgBox').scrollTop = $('msgBox').scrollHeight;
}

function logInfo(text) {
	log('- INFO: ' + text);
}

function logError(text) {
	log('- ERROR: ' + text);
}

// Retrieves URL parameter by name
function getUrlParam(name) {
	var regexS = "[\\?&]"+name+"=([^&#]*)";
	var regex = new RegExp(regexS);
	var results = regex.exec(decodeURIComponent(window.location.href));
	if(results == null) {
		return null;
	} else {
		return results[1];
	}
}

// Updates the window title and the header title with the vm name
function setVmName() {
	var title = getUrlParam('vmName');
	logInfo('Set window title to: [' + title + ']'); 
	window.document.title = title;
	
	logInfo('Set header label to: [' + title + ']');
	document.getElementById('vmNameLabel').innerHTML = title;
}

// Initializes/loads VMRC native plugin.
function createPluginObject(parentId) {
	logInfo('Create the VMRC plugin object.');
	var obj = document.createElement("object");
	obj.setAttribute("id", "vmrc");
	obj.setAttribute("height", "100%");
	obj.setAttribute("width", "100%");
	if (isIE) {
		obj.setAttribute("classid", clsid);
	} else {
		obj.setAttribute("type", mimetype);
	}
	
	$(parentId).appendChild(obj);   
	return $('vmrc');
}

// Wrapper function to hide the browser-specific differences in binding handlers to events.
function attachEventHandler(eventName, handler) {
	logInfo('Attaching event handler for: [' + eventName + ']');
	
	if (isIE) {
		vmrc.attachEvent(eventName, handler);
	} else {
		vmrc[eventName] = handler;
	}
}

// For handling message events
function onMessageHandler(type, message) {	
	// Try to handle errors possibly caused by invalid advancedConfig on startup
	if (type == VMRC_MESSAGE_ERROR) {
		logError('Received message - type: [' + type + '], message: [' + message + ']');
		alert('Received error message: "' + message + '"');
	} else {
		logInfo('Received message - type: [' + type + '], message: [' + message + ']');
	}
}

// For handling connection state changes
function onConnectionStateChangeHandler(
	cs, host, datacenter, vmId, userRequested, reason) {
	
	logInfo('Connection state changed to: [' + cs + ']. Reason: [' + reason + ']');
	
	if (cs == VMRC_CS_CONNECTED) {
		if (getUrlParam('fullscreen') == true) {
			setFullscreen();
		}
	}
}

// Helper function for browser-specific VMRC constants initialization
function initVmrcConstants() {
	if (isIE) {
		VMRC_MESSAGE_ERROR = vmrc.VMRC_MessageType("VMRC_MESSAGE_ERROR")
		VMRC_CS_CONNECTED = vmrc.VMRC_ConnectionState("VMRC_CS_CONNECTED")
		VMRC_MKS = vmrc.VMRC_Mode("VMRC_MKS")
		VMRC_EVENT_MESSAGES = vmrc.VMRC_MessageMode("VMRC_EVENT_MESSAGES")
	} else {
		VMRC_MESSAGE_ERROR = vmrc.VMRC_MessageType.VMRC_MESSAGE_ERROR;
		VMRC_CS_CONNECTED = vmrc.VMRC_ConnectionState.VMRC_CS_CONNECTED;
		VMRC_MKS = vmrc.VMRC_Mode.VMRC_MKS;
		VMRC_EVENT_MESSAGES = vmrc.VMRC_MessageMode.VMRC_EVENT_MESSAGES;
	}
}

// Initializes the VMRC plugin and connects it to the VM specified in the URL params.
function init() {
	// If the message box is visible - make room for it, because the plugin panel is stretched to the bottom.
	if ($("msgBox").style.display != "none") {
		$("pluginPanel").style.bottom = "300px";
	}

	logInfo('Begin initialization');
	setVmName();
	vmrc = createPluginObject("pluginPanel");

	if (vmrc == null) {
		logError('VMRC object is null. Abort');
		alert('Unable to initialize the VMRC plugin. Make sure the plugin is installed.');
		return;
	}
	
	initVmrcConstants();

	attachEventHandler("onMessage", onMessageHandler);
	attachEventHandler("onConnectionStateChange", onConnectionStateChangeHandler);
	
	startup();
	connect();
}

// Disconnects and shutdowns the VMRC plugin
function destroy() {
	logInfo('Dispose of VMRC object');
	disconnect();
	shutdown();
}

// Invokes plugin startup() method which executes native code to initialize a VMRC instance and start a peer vmware-vmrc process.
function startup() {
	var advancedConfiguration = '';
	tunnelConnection = getUrlParam('tunnelConnection');
	
	if (tunnelConnection == 1) {
		advancedConfiguration = 'usebrowserproxy=true;tunnelmks=true';
	}
	
	logInfo('Startup VMRC with the following parameters:');
	logInfo('--- VMRC mode: [MKS]');
	logInfo('--- VMRC message mode: [EVENT_MESSAGES]');
	logInfo('--- AdvancedConfiguration: [' + advancedConfiguration + ']');
	
	try {
		var ret = vmrc.startup(VMRC_MKS, VMRC_EVENT_MESSAGES, advancedConfiguration);
		logInfo('Startup of VMRC succeeded.')
	} catch(err) {
		logError('Startup of VMRC failed: [' + err + ']');
		alert('Startup of VMRC failed: [' + err + ']');
	}
}

// Invokes plugin shutdown() method, stops corresponding vmware-vmrc peer process.
function shutdown() {
	logInfo('Shutdown VMRC');
	
	try {
		vmrc.shutdown();
	} catch(err) {
		logError('Unable to shutdown VMRC: [' + err + ']');
		alert('Unable to shutdown VMRC: [' + err + ']');
		return;
	}
}

 // Connects the VMRC to the VM using the parameters passed in the URL
function connect() {
	var host = getUrlParam('host');
	var ticket = getUrlParam('ticket');
	var vmid = getUrlParam('vmid');
	
	logInfo('Connecting to VMRC with the following parameters:');
	logInfo('--- host: [' + host + ']');
	logInfo('--- vmid: [' + vmid + ']');
	logInfo('--- ticket: [' + ticket + ']');
	
	try {
		// Connect to the VMRC. The parameters respectively are:
		// host, host certificate thumbprint, allowSSLErrors, ticket, username, password, vmid, datacenter, vmPath
		var ret = vmrc.connect(host, '', true, ticket, '', '', vmid, '', '');
	
		logInfo('Successfully connected to VMRC.');
	} catch (err) {
		logError('Unable to connect to VMRC: [' + err + ']');
		alert('Unable to connect to VMRC: [' + err + ']');
	}
}

// Invokes plugin disconnect() method, terminates any related connection-specific child processes.
function disconnect() {
	logInfo('Disconnecting VMRC');
	
	try {
		vmrc.disconnect();
	} catch (err) {
		logError('Unable to disconnect VMRC: [' + err + ']');
		alert('Unable to disconnect VMRC: [' + err + ']');
		return;
	}
}

// Open the console in full screen. The VMRC must be connected (and fully initialized) prior to calling this.
function setFullscreen() {
	if (vmrc.getConnectionState() == VMRC_CS_CONNECTED) {
		logInfo('Opening in fullscreen.');
		vmrc.setFullscreen(true);
	}
}

// Send Ctrl+Alt+Delete to the VM
function sendCAD() {
	try {
		logInfo('Sending Ctrl+Alt+Delete to the VM.');
		vmrc.sendCAD();
	} catch (err) {
		logError('Send CAD call failed: ' + err.description);
		return;
	}
}