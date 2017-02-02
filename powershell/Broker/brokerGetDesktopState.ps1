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
        Get desktop state

	.DESCRIPTION
        This command get states of desktops in pools.
		This command could execute on multiple brokers and pools.
		
	.FUNCTIONALITY
		Broker
	
	.NOTES
		AUTHOR: Jerry Liu
		EMAIL: liuj@vmware.com
#>

Param (
	[parameter(
		HelpMessage="IP or FQDN of the ESX or VC server where the broker VM is located"
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
		HelpMessage="Name of broker VM or IP / FQDN of broker machine. Support multiple values seperated by comma. VM name and IP could be mixed."
	)]
	[string]
		$vmName, 
	
	[parameter(
		HelpMessage="User of broker (default is administrator)"
	)]
	[string]	
		$guestUser="administrator", 
		
	[parameter(
		HelpMessage="Password of guestUser"
	)]
	[string]	
		$guestPassword=$env:defaultPassword,
		
	[parameter(
		Mandatory=$true,
		HelpMessage="Pool ID. Support multiple values seperated by comma. Default is '*' for all pools"
	)]
	[string]
		$poolId='*'
)

foreach ($paramKey in $psboundparameters.keys) {
	$oldValue = $psboundparameters.item($paramKey)
	$newValue = [System.Net.WebUtility]::urldecode("$oldValue")
	set-variable -name $paramKey -value $newValue
}

. .\objects.ps1

$getDesktopState = {
	Param ($poolId)
	Add-PSSnapin -Name vmware* -ea SilentlyContinue | out-null
	function GetDesktopVMState { 
		param ($Desktop,$pool,$sessions)
		if($Desktop.GetType().Name -eq "DesktopVM"){
			if($Desktop.isInPool -eq "false"){
				write-host "notManagedByView"
				break
			}
			$machine_id = $Desktop.machine_id
			$serverObject = [ADSI]("LDAP://localhost:389/cn=" + $machine_id + ",ou=Servers,dc=vdi,dc=vmware,dc=int")		
			$stateString = "Unknown"
			$vmState = $serverObject.get("pae-VMState")
			$localState = $Desktop.localState
			$desktop_sessions = @()
			foreach ($session in $sessions) {
				if($session.session_id -match $machine_id){
					$desktop_sessions += $session
				}
			}
			try {
				$dirtyForNewSessions = $serverObject.get("pae-DirtyForNewSessions")
				$dirtyForNewSessions = $dirtyForNewSessions -and ($dirtyForNewSessions -ne "0")
			} catch { 
				$dirtyForNewSessions = $false
			}
			if (($vmState -eq "CLONING") -or ($vmState -eq "UNDEFINED") -or ($vmState -eq "PRE_PROVISIONED")) {
				$stateString = "Provisioning";
			} elseif ($vmState -eq "CLONINGERROR") {
				$stateString = "ProvisionErr";
			} elseif ($vmState -eq "CUSTOMIZING") {
				if ($pool -and ($pool.deliveryModel -ne "Provisioned")) {
					$stateString = "WaitingForAgent";
				} else {
					$stateString = "Customizing";
				}
			} elseif ($vmState -eq "DELETING") {
				$stateString = "Deleting";
			} elseif ($localState -and ($localState -ne "checked in")) {
				$stateString = "VmStateCheckedOut";
			} elseif ($vmState -eq "MAINTENANCE") {
				$stateString = "Maintenance";
			} elseif ($vmState -eq "ERROR") {
				$stateString = "Error";
			} elseif ($desktop_sessions.length -gt 0) {
				$unassignedUserSession = $false
				if (($pool.persistence -eq "Persistent") -and ($Desktop.user_sid.Length -le 0) -or ($Desktop.user_displayname -ne $desktop_sessions[0].Username)) {
					$unassignedUserSession = $true
				}
				if ($desktop_sessions[0].state -eq "CONNECTED") {
					if ($unassignedUserSession) {
						$stateString = "UnassignedUserConnected";
					} else {
						$stateString = "Connected";
					}
				} else {
					if ($unassignedUserSession) {
						$stateString = "UnassignedUserDisconnected";
					} else {
						$stateString = "Disconnected";
					}
				}
			} elseif ($isDirtyForNewSessions) {
				$stateString = "AlreadyUsed";
			} elseif ($vmState -eq "READY") {
				$stateString = "Available"
			} else {
				Write-Error ("Failed to determine state for VM: " + $Desktop.Name)
				break
			}
			$stateString;			
		} else {
			Write-Error "Object is not a DesktopVM."
		}
	}
	function outputTable{
		param($pool)
		$desktops = Get-DesktopVM -IsInPool $true -pool_id $pool.pool_id -ea SilentlyContinue
		$sessions = (Get-RemoteSession -pool_id $pool.pool_id -ea SilentlyContinue)
		if ($desktops) {
			foreach ($desktop in $desktops){
				$state = GetDesktopVMState $desktop $pool $sessions
				write-output "<desktop>"
				Write-Output ("<poolid>" + $desktop.pool_id + "</poolid>")
				Write-Output ("<desktopname>" + $desktop.Name + "</desktopname>")
				Write-Output ("<assigneduser>" + $desktop.user_displayname + "</assigneduser>")
				Write-Output ("<state>" + $state + "</state>")
				write-output "</desktop>"
			}
		}
	}	
	$poolIdList = $poolId.split(",") | %{$_.trim()}
	$pools = get-pool -pool_id $poolIdList -ea SilentlyContinue
	foreach ($p in $pools) {
		outputTable($p)
	}
}

$ipList = getVmIpList $vmName $serverAddress $serverUser $serverPassword
$ipList | % {
	$remoteWinBroker = newRemoteWinBroker $_ $guestUser $guestPassword
	$remoteWinBroker.initialize()
	try {
		invoke-command -scriptBlock $getDesktopState -session $remoteWinBroker.session -EA stop -argumentlist $poolId
	} catch {
		writeCustomizedMsg "Fail - get desktop state"
		writeStderr
		[Environment]::exit("0")
	}
	writeCustomizedMsg "Success - get desktop state"
}