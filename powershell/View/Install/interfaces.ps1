<#
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
#>

<#
	.SYNOPSIS
		Install on Windows

	.DESCRIPTION
		This command installs View components on remote Windows machine.
    
  .FUNCTIONALITY
    View
		
	.NOTES
		AUTHOR: Jian Liu
		EMAIL: liuj@vmware.com
#>

Param (
	[parameter(
		Mandatory=$true,
		HelpMessage="IP / FQDN of target Windows machine"
	)]
	[string]
		$winAddress, 
	
	[parameter(
		HelpMessage="User of target Windows machine (default is administrator)"
	)]
	[string]	
		$winUser="administrator", 
		
	[parameter(
		HelpMessage="Password of winUser"
	)]
	[string]	
		$winPassword=$env:defaultPassword,
    
	[parameter(
    mandatory=$true,
		HelpMessage="Type of the View component to install"
	)]
  [ValidateSet(
		"blast",
    "agent",
    "agent-ts",
    "agent-unmanaged",
    "agent-composer",
    "broker",
    "broker-replica",
    "broker-security",
    "broker-transfer",
		"other"
	)]
	[string]
    $type, 
	
  [parameter(
    mandatory=$true,
		HelpMessage="URL to the installer file"
	)]
  [string]
    $installerUrl,
  
  [parameter(
		HelpMessage="IP of standard broker"
	)]
  [string]
    $stdBrokerIp,
  
  [parameter(
		HelpMessage="Customized parameters for silent install"
	)]
  [string]
    $silentInstallParam
)

. .\utils.ps1
$web = new-object net.webclient
iex $web.downloadstring('http://bit.ly/1Je9cuh') # windows\object.ps1

$remoteWin = newRemoteWin $winAddress $winUser $winPassword
$installer = ($installerUrl.split("/"))[-1]
$cmd = {
  new-item c:\temp -type directory -force | out-null
  $wc = new-object system.net.webclient;
  $wc.downloadfile("$using:installerUrl", "c:\temp\$using:installer");
  get-item "c:\temp\$using:installer" -ea Stop | out-null
}

$remoteWin.executePsRemote($cmd, $null, "download file $installer", "1200")
#$remoteWin.sendFile("..\postinstall\instDrv.exe","c:\temp\instDrv.exe")

if ($silentInstallParam) {
  $cmdPara = $silentInstallParam
  $task = 'c:\temp\' + $installer + " " + $silentInstallParam.replace('"', '\"')
} else {
  switch($type) {
    "blast" {
      $cmdPara = ' /s /v"/qn deploymode=view"'
    }
    "agent-ts" {
      $cmdPara = ' /s /v"/qn RebootYesNo=Yes REBOOT=Suppress VDM_SERVER_USERNAME=' + $winUser + ' VDM_SERVER_PASSWORD=' + $winPassword + ' VDM_SERVER_NAME=' + $stdBrokerIp + '"'
      $task = 'c:\temp\' + $installer + ' /s /v\"/qn RebootYesNo=Yes REBOOT=Suppress ADDLOCAL=ALL VDM_SERVER_USERNAME=administrator VDM_SERVER_PASSWORD=' + $winPassword + ' VDM_SERVER_NAME=' + $stdBrokerIp + '\"'
    }
    "agent" {
      $cmdPara = ' /s /v"/qn RebootYesNo=No REBOOT=ReallySuppress VDM_FORCE_DESKTOP_AGENT=1 VDM_SERVER_USERNAME=' + $winUser + ' VDM_SERVER_PASSWORD=' + $winPassword + ' VDM_SERVER_NAME=' + $stdBrokerIp + '"'
    }
    "agent-unmanaged" {
      $cmdPara = ' /s /v"/qn RebootYesNo=No REBOOT=ReallySuppress VDM_VC_MANAGED_AGENT=0 VDM_SERVER_USERNAME=' + $winUser + ' VDM_SERVER_PASSWORD=' + $winPassword + ' VDM_SERVER_NAME=' + $stdBrokerIp + '"'
    }
    "agent-composer" {
      $cmdPara = ' /q'
    }
    "broker" { 
      $task = 'c:\temp\' + $installer + ' /s /v\"/qn VDM_SERVER_INSTANCE_TYPE=1 VDM_SERVER_RECOVERY_PWD=111111\"'
    }
    "broker-replica" {
      $task = 'c:\temp\' + $installer + ' /s /v\"/qn ADDLOCAL=ALL VDM_SERVER_INSTANCE_TYPE=2 ADAM_PRIMARY_NAME=' + $stdBrokerIp + '\"'
    }
    "broker-security" {
      $sysinfo = invoke-command {Get-WmiObject -Class Win32_ComputerSystem} -session $remoteWin.session
      $hostFQDN = "{0}.{1}" -f $sysinfo.Name, $sysinfo.Domain
      $cmdPara = ' /s /v"/qn ADDLOCAL=ALL VDM_SERVER_INSTANCE_TYPE=3 VDM_SERVER_SS_PWD=111111 VDM_SERVER_SS_EXTURL=https://' + $hostFQDN + ':443 VDM_SERVER_SS_FORCE_IPSEC=0 VDM_SERVER_SS_PCOIP_IPADDR=' + $winAddress + ' VDM_SERVER_SS_PCOIP_TCPPORT=4172 VDM_SERVER_SS_PCOIP_UDPPORT=4172 VDM_SERVER_NAME=' + $stdBrokerIp + ' VDM_SERVER_SS_BSG_EXTURL=https://' + $hostFQDN + ':8443 "'
    }
    "broker-transfer" {
      $sysinfo = invoke-command {Get-WmiObject -Class Win32_ComputerSystem} -session $remoteWin.session
      $hostFQDN = "{0}.{1}" -f $sysinfo.Name, $sysinfo.Domain
      $curDomain = $sysinfo.Domain
      $adminEmail = "admin@$curDomain"
      $cmdPara = ' /s /v"/qn ADDLOCAL=ALL VDM_SERVER_INSTANCE_TYPE=4 SERVERDOMAIN=' + $curDomain + ' SERVERNAME=' + $hostFQDN + ' SERVERADMIN=' + $adminEmail + '"'
    }
    default {
      $cmdPara = ' /s /v"/qn RebootYesNo=No REBOOT=ReallySuppress ADDLOCAL=ALL"'
    }
  }
}

if (("broker","broker-replica") -contains $type) {
  $argList = @($winUser, $winPassword, $task)
  $cmd = {
    remove-item -path "$env:temp\vminst*.log" -force -ea silentlyContinue
    remove-item -path "$env:temp\vmmsi*.log" -force -ea silentlyContinue
    $date = get-date '12/31/2014'.replace('2014',(get-date).year+1) -format (Get-ItemProperty -path 'HKCU:\Control Panel\International').sshortdate
    schtasks /f /create /tn installView /ru $args[0] /rp $args[1] /rl HIGHEST /sc once /sd $date /st 00:00:00 /tr $args[2] | out-null
    schtasks /run /tn installView | out-null
    netsh advfirewall firewall set rule name="Remote Scheduled Tasks Management (RPC)" new profile=any remoteip=any enable=yes | out-null
    netsh advfirewall firewall set rule name="Remote Scheduled Tasks Management (RPC-EPMAP)" new profile=any remoteip=any enable=yes | out-null
  }
  start-sleep 30
  $remoteWin.executePsRemote($cmd, $argList, "trigger broker installation task")
  $remoteWin.waitForTaskComplete("installView", 2400)
  $cmd = {
    schtasks /delete /f /tn installView | out-null
    $log = get-content "$env:temp\vmmsi*.log"
    $result = $log | select-string "installation operation completed successfully"
    if (!$result) {throw "installation failed, please check $env:temp\vmmsi.log."}
  }
  $remoteWin.executePsRemote($cmd, $null, "install $installer")
} else {
  $cmd = {    
    #start-process c:\temp\instDrv.exe
    $installprocess = [System.Diagnostics.Process]::Start("c:\temp\$using:installer", "$using:cmdPara")
    $installprocess.WaitForExit()
    #stop-process -name instDrv
    If ((0,3010) -notcontains $installprocess.ExitCode) {    
        throw ("Fail to install $using:installer. Exit code:" + $installprocess.ExitCode)
    }
  }

  $remoteWin.executePsRemote($cmd, $null, "install $installer")
}

if ($type -notmatch "broker") {
  $remoteWin.restart()
} else {
  $msg = "enable telnet server"
  $argList = @()
  $cmd = {
    Import-Module servermanager | out-null
    Add-WindowsFeature Telnet-Server | out-null
    Set-Service TlntSvr -StartupType Automatic -Status Running | out-null
    tlntadmn config maxconn = 100 | out-null
    tlntadmn config timeout = 24:00:00 | out-null
  }
  $remoteWin.executePsRemote($cmd, $argList, $msg)
}
