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

## Author: Jerry Liu, liuj@vmware.com

Param ($poolId='*')

Add-PSSnapin -Name vmware.view.broker -ErrorAction SilentlyContinue | out-null

function GetDesktopVMState
{ param ($Desktop,$pool,$sessions)
	# Verify this is a DesktopVM
	if($Desktop.GetType().Name -eq "DesktopVM"){

		if($Desktop.isInPool -eq "false"){
			#Write-Error ("The desktop $Desktop.Name is not managed by View.")
			write-host "notManagedByView"
			break
		}
		# Obtain server object from ADAM
		$machine_id = $Desktop.machine_id
		$serverObject = [ADSI]("LDAP://localhost:389/cn=" + $machine_id + ",ou=Servers,dc=vdi,dc=vmware,dc=int")
				
		$stateString = "Unknown"

		# Retrieve VM and local state
		$vmState = $serverObject.get("pae-VMState")
		$localState = $Desktop.localState

		# Retrieve the pool for this VM
		# $pool = ($Desktop | Get-Pool)
		
		# Construct a list of any remote sessions for this VM
		# $sessions = (Get-RemoteSession -pool_id $Desktop.pool_id -ErrorAction SilentlyContinue)
		$desktop_sessions = @()
		foreach ($session in $sessions) {
			if($session.session_id -match $machine_id){
				$desktop_sessions += $session
			}
		}

		# Retrieve DirtyForNewSessions attribute
		# Catch exception if not present in ADAM
		try {
		
			$dirtyForNewSessions = $serverObject.get("pae-DirtyForNewSessions")
			$dirtyForNewSessions = $dirtyForNewSessions -and ($dirtyForNewSessions -ne "0")
		
		} catch { 
			$dirtyForNewSessions = $false
		}
		
		## Determine state based on retrieved details
		
		# order 1
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

		# order 3
		} elseif ($desktop_sessions.length -gt 0) {
			$unassignedUserSession = $false
			if (($pool.persistence -eq "Persistent") -and ($Desktop.user_sid.Length -le 0) -or ($Desktop.user_displayname -ne $desktop_sessions[0].Username)) {
				# If the VM is in a persistent pool, has an owner, and this
				# session belongs to a different user, or has no owner but has
				# a session, then flag it.
				$unassignedUserSession = $true
			}
			
			# Output relevant session state
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

		
		# order 4
		} elseif ($isDirtyForNewSessions) {
			$stateString = "AlreadyUsed";
		} elseif ($vmState -eq "READY") {
			$stateString = "Available"
			# if($Desktop.IPAddress){
				# $agentState = vdmadmin -A -d $Desktop.pool_id -m $Desktop.Name -getstatus
				# $agentErrorCode = $agentState -match "agentErrorCode = .*"
				# $agentErrorCode = ($agentErrorCode -replace "agentErrorCode = ", "")
				# if($agentErrorCode -eq "0"){
					# $stateString = "Available"
				# } else {
					# $stateString = "AgentUnreachable"
				# }
			# } else {
				# $stateString = "AgentUnreachable"
			# }

		# order 5 - otherwise
		} else {
			Write-Error ("Failed to determine state for VM: " + $Desktop.Name)
			break
		}
		
		# Output determined status
		$stateString;
				
	} else {
		Write-Error "Object is not a DesktopVM."
	}
}

####	Output the status of all View desktop VMs using
####	GetDesktopVMState(...)
####	For visual inspection.
function outputTable
{
	param($pool)
	$desktops = Get-DesktopVM -IsInPool $true -pool_id $pool.pool_id -ea Stop
	$sessions = (Get-RemoteSession -pool_id $pool.pool_id -ErrorAction SilentlyContinue)
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


if ($poolId -ne '*') {
	$p = get-pool -pool_id $poolId -ea silentlycontinue
	if ($p) {
		outputTable($p)
	} else {
		"<stdOutput>$poolId does not exist</stdOutput>"
	}
} else {
	$pools = get-pool
	foreach ($p in $pools) {
		outputTable($p)
	}
}