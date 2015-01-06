<#
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
#>

<#
	.SYNOPSIS
        Synchronize time on ESX and VM

	.DESCRIPTION
        This command synchronizes time of ESX hosts and VMs to an NTP server.
		This command could execute on multiple ESX or VC servers to 
		synchronize all ESX hosts and VMs.
	
		
	.FUNCTIONALITY
		vSphere
		
	.NOTES
		AUTHOR: Jerry Liu
		EMAIL: liuj@vmware.com
#>

Param (
	[parameter(
		Mandatory=$true,
		HelpMessage="IP or FQDN of the ESX or VC server. Support multiple values seperated by comma."
	)]
	[string]
		$serverAddress, 
	
	[parameter(
		HelpMessage="User name to connect to the server (default is root)"
	)]
	[string]	
		$serverUser="root", 
	
	[parameter(
		HelpMessage="Password of the user"
	)]
	[string]	
		$serverPassword=$env:defaultPassword, 
	
	[parameter(
		Mandatory=$true,
		HelpMessage="IP or FQDN of the NTP server"
	)]
	[string]
		$ntpServerAddress
)

foreach ($paramKey in $psboundparameters.keys) {
	$oldValue = $psboundparameters.item($paramKey)
	$newValue = [system.web.httputility]::urldecode("$oldValue")
	set-variable -name $paramKey -value $newValue
}

. .\objects.ps1

$serverAddressList = $serverAddress.split(",") | %{$_.trim()}
foreach ($serverAddress in $serverAddressList) {
	$server = newServer $serverAddress $serverUser $serverPassword 
	get-vmhost -Server $server.viserver | % {
		try {
			$_ | add-vmhostNtpServer $ntpServerAddress -ea SilentlyContinue
			$_ | Get-VMHostFirewallException | where {$_.Name -eq "NTP client"} | `
				Set-VMHostFirewallException -Enabled:$true
			$_ | Get-VmHostService | ? {$_.key -eq "ntpd"} | Start-VMHostService
			$_ | Get-VmHostService | ? {$_.key -eq "ntpd"} | Set-VMHostService -policy "automatic"
			writeCustomizedMsg "Success - configure NTP settings for vmhost $($_.name)"
		} catch {
			writeCustomizedMsg "Fail - configure NTP settings for vmhost $($_.name)"
			writeStderr
		}
	}
	get-vm -Server $server.viserver | % {
		try {
			$spec = New-Object VMware.Vim.VirtualMachineConfigSpec
			$spec.changeVersion = $_.ExtensionData.Config.ChangeVersion
			$spec.tools = New-Object VMware.Vim.ToolsConfigInfo
			$spec.tools.syncTimeWithHost = $true
			$_this = Get-View -Id $_.Id -server $server.viserver
			$_this.ReconfigVM_Task($spec)
			writeCustomizedMsg "Success - configure time sync settings for vm $($_.name)"
		} catch {
			writeCustomizedMsg "Fail - configure time sync settings for vm $($_.name)"
			writeStderr
		}
	}
}