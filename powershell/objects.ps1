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
		This file defines common objects and functions used by other scripts.
		
	.FUNCTIONALITY
		noshow
	
	.NOTES
		AUTHOR: Jerry Liu
		EMAIL: liuj@vmware.com
#>

#$errorActionPreference = "SilentlyContinue"
$current = $host.ui.rawui.buffersize
$current.width = 128
$host.ui.rawui.buffersize = $current
$current = $host.ui.rawui.windowsize
$current.width = 128
$host.ui.rawui.windowsize = $current

$runFromWeb = [boolean]$env:runFromWeb

function verifyIp {
	param($ipAddress)
	try {
		#$ipObj = [System.Net.IPAddress]::parse($ipAddress)
		#$isValidIP = [System.Net.IPAddress]::tryparse([string]$ipAddress, [ref]$ipObj)
		$ip = ([System.Net.Dns]::GetHostAddresses($ipaddress)).IPAddressToString
	} catch {
		return $false
	}
	return $ip
	# if ($isValidIP) {
	   # return $true
	# } else {
	   # return $false
	# }
}

function getUniqueString {
	Param($length)
	
	$rand = new-object System.Random
	1..$length | foreach { $string = $string + [char]$rand.next(101,107) }
	return $string
}

function newUnc {
	Param($path,$disk,$user,$passwd)
	
	$unc = New-Object PSObject -Property @{
		path = $path
		disk = $disk
		user = $user
		passwd = $passwd
	}
	
	$unc | add-member -MemberType ScriptMethod -Value {
		if ( (get-psdrive -name $this.disk -ErrorAction SilentlyContinue) -eq $null ){
			#$drive = new-object -com wscript.network
			#$drive.MapNetworkDrive($this.disk + ":", $this.path, $false, $this.user, $this.passwd)
			$cmd = "net use " + $this.disk + ": " + $this.path + " " + $this.passwd + " /user:" + $this.user
			invoke-expression $cmd
		} 
	} -name mount
	
	return $unc
}

function newSshServer { ##Server supports SSH access
	Param($address, $user, $password)
	try {
		import-module posh-ssh -ea stop
	} catch {
		writeCustomizedMsg "Fail - import POSH-SSH module"
		writeCustomizedMsg "Info - need to install POSH-SSH on webcommander server https://github.com/darkoperator/Posh-SSH"
		writeStderr
		[Environment]::exit("0")
	}
	$cred = new-object -typeName System.management.automation.pscredential -argumentList $user, (ConvertTo-SecureString $password -asPlainText -Force)
	try {
		get-sshtrustedhost | remove-sshtrustedhost
		$sshSession = new-sshsession -computername $address -credential $cred -AcceptKey $true
		$sftpSession = new-sftpsession -computername $address -credential $cred -AcceptKey $true
	} catch {
		writeCustomizedMsg "Fail - connect to SSH server $address"
		writeStderr
		[Environment]::exit("0")
	}

	$sshServer = New-Object PSObject -Property @{
		address = $address
		user = $user
		password = $password
		sshSession = $sshSession
		sftpSession = $sftpSession
	}
	
	$sshServer | add-member -MemberType ScriptMethod -value {
    param($cmd, $outputCheck, $pattern)
		$cmd = $cmd -replace "`r`n","`n"
		try {
			$result = invoke-sshcommand -command $cmd -sshSession $this.sshSession -ea stop
		} catch {
			writeCustomizedMsg "Fail - run SSH script"
			writeStderr
			[Environment]::exit("0")
		}
		if ($result.exitStatus -eq 0) {
			writeCustomizedMsg "Success - run SSH script"
			if ($pattern) {
				try {
					$verification = invoke-expression "'$($result.output)' -$outputCheck '$pattern'"
					if ($verification) {
						writeCustomizedMsg "Success - verify SSH script output"
					} else {
						writeCustomizedMsg "Fail - verify SSH script output"
					}
				} catch {
					writeCustomizedMsg "Fail - syntax error to verify SSH script"
					writeStderr
					[Environment]::exit("0")
				}
			}
		} else {
			writeCustomizedMsg "Fail - run SSH script"
			writeStdout $result.error
		}
		if ($result.output) {writeStdout $result.output}
	} -name runCommand
	
	$sshServer | add-member -MemberType ScriptMethod -value {
        param($localFile, $remotePath)
		$fileName = ($localFile.split("\"))[-1]
		try {
			set-sftpfile -sftpsession $this.sftpsession -localfile $localFile -remotePath $remotePath -ea stop
			writeCustomizedMsg "Success - copy file $fileName to $($this.address)"
		} catch {
			writeCustomizedMsg "Fail - copy file $fileName to $($this.address)"
			writeStderr
			#[Environment]::exit("0")
		}
	} -name copyFileSftp
	
	$sshServer | add-member -MemberType ScriptMethod -value {
        param($localFile, $remoteFile)
		try {
			"y" | set-scpfile -computername $this.address -credential $cred -localfile $localFile -remotePath $remoteFile
		} catch {
			writeCustomizedMsg "Fail - copy file via SCP"
			writeStderr
			[Environment]::exit("0")
		}
		writeCustomizedMsg "Success - copy file via SCP"
	} -name copyFileScp
	
	return $sshServer
}

function newServer { ##viServer, including ESX and VC
	Param($address, $user, $password)

	Import-Module -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue
	
	try {
		$viserver = connect-VIServer $address -user $user -password $password -NotDefault -wa 0 -EA stop
	} catch {
		writeCustomizedMsg "Fail - connect to server $address"
		writeStderr
		[Environment]::exit("0")
	}

	$server = New-Object PSObject -Property @{
		address = $address
		user = $user
		password = $password
		viserver = $viserver
	}
	
	$server | add-member -MemberType ScriptMethod -value {
        param($vmName)
		$vm = get-vm $vmName -server $this.viserver
		$folder = $vm.folder
		$path = "/" + $folder.name + "/" + $vmName
		while($folder.Parent){
			$folder = $folder.Parent
			$path = "/" + $folder.Name + $path
		}
		writeCustomizedMsg "Info - VM path on server $ip is $path"
		return $path
	} -name getVmPath
	
	writeCustomizedMsg "Success - connect to server $($server.address)"
	writeCustomizedMsg "Info - server is of product line: $($server.viserver.productline.toUpper())"
	
	return $server
}

function newVmWin {
	Param($server,$name,$guestUser,$guestPassword)

	$vm = newVm $server $name $guestUser $guestPassword
	
	$vm | add-member -MemberType ScriptMethod -Value { ##checkPs
		$cmd = 'Powershell -noprofile -command $PSVersionTable.PSVersion.major'
    try {
      [int]$psVer = $this.runScript($cmd, "Bat")
      writeCustomizedMsg "Info - Powershell $psVer is installed in target VM"
      return $true
    } catch {
			writeCustomizedMsg "Info - Powershell is NOT installed in target VM"
			return $false
		}
	} -name checkPs
	
	$vm | add-member -MemberType ScriptMethod -Value { ##installPs
		if ($this.checkPs()) {
			return
		}
		$gosName = (Get-VMGuest $this.vivm).OSFullName

		if ($gosName -like "* XP *(32-bit)") {
			$this.copyFileToVm("..\postinstall\dotNet\netfx20sp1_x86.exe","c:\temp\")
			$this.copyFileToVm("..\postinstall\powershell\X86-en-windowsxp-kb968930-x86-eng.exe","c:\temp\")
			$cmd = @"
c:\temp\netfx20sp1_x86.exe /qb /norestart
c:\temp\X86-en-windowsxp-kb968930-x86-eng.exe /quiet /norestart
"@
		} 
		elseif ($gosName -like "* XP *(64-bit)")
		{
			$this.copyFileToVm("..\postinstall\dotNet\netfx20sp1_x64.exe","c:\temp\")
			$this.copyFileToVm("..\postinstall\powershell\WindowsServer2003.WindowsXP-KB926139-v2-x64-ENU.exe","c:\temp\")
			$cmd = @"
c:\temp\netfx20sp1_x64.exe /qb /norestart
c:\temp\WindowsServer2003.WindowsXP-KB926139-v2-x64-ENU.exe /passive /norestart
"@
		}
		elseif ($gosName -like "* 2003 *(32-bit)")
		{
			$this.copyFileToVm("..\postinstall\dotNet\netfx20sp1_x86.exe","c:\temp\")
			$this.copyFileToVm("..\postinstall\powershell\X86-en-windowsserver2003-kb968930-x86-eng.exe","c:\temp\")
			$cmd = @"
c:\temp\netfx20sp1_x86.exe /qb /norestart
c:\temp\X86-en-windowsserver2003-kb968930-x86-eng.exe /quiet /norestart
"@
		}
		elseif ($gosName -like "* 2003 *(64-bit)")
		{
			$this.copyFileToVm("..\postinstall\dotNet\netfx20sp1_x64.exe","c:\temp\")
			$this.copyFileToVm("..\postinstall\powershell\AMD64-en-windowsserver2003-kb968930-x64-eng.exe","c:\temp\")
			$cmd = @"
c:\temp\netfx20sp1_x64.exe /qb /norestart
c:\temp\AMD64-en-windowsserver2003-kb968930-x64-eng.exe /quiet /norestart
"@
		}
		elseif (($gosName -like "* Vista *(32-bit)") `
			-or ($gosName -like "* 2008 *(32-bit)"))
		{
			$this.copyFileToVm("..\postinstall\powershell\X86-all-windows6.0-kb968930-x86.msu","c:\temp\")
			$cmd = "c:\temp\X86-all-windows6.0-kb968930-x86.msu /quiet /norestart"
		}
		elseif (($gosName -like "* Vista *(64-bit)") `
			-or ($gosName -like "* 2008 *(64-bit)"))
		{
			$this.copyFileToVm("..\postinstall\powershell\AMD64-all-windows6.0-kb968930-x64.msu","c:\temp\")
			$cmd = "c:\temp\AMD64-all-windows6.0-kb968930-x64.msu /quiet /norestart"
		}
		
		cmd += @"
		
powershell set-executionpolicy unrestricted -confirm:`$false
"@
		$this.runScript($cmd,"Bat")
		if ($this.checkPs()) {
			writeCustomizedMsg "Succeed - install Powershell in the target VM"
		} else {
			writeCustomizedMsg "Fail - install Powershell in the target VM"
			[Environment]::exit("0")
		}
	} -name installPs
	
	# $vm | add-member -MemberType ScriptMethod -Value { ##checkPsRemote
		# $cmd = '(get-service winrm).status.toString().toLower()'
		# $winRmStatus = $this.runScript($cmd, "Powershell")
		# writeCustomizedMsg "Info - WinRM service is $winRmStatus in target VM"
		# if ($winRmStatus -match "running") {
			# return $true
		# } else {
			# return $false
		# }
	# } -name checkPsRemote
	
	$vm | add-member -MemberType ScriptMethod -Value { ##checkPsRemote
		$cred = new-object -typeName System.management.automation.pscredential -argumentList $this.user, (ConvertTo-SecureString $this.password -asPlainText -Force)
		$version = invoke-command -scriptblock {$PSVersionTable.PSVersion.major} -computername $this.getIPv4() -cred $cred -wa 0 -EA SilentlyContinue
		if ($version -ge 2) {
			writeCustomizedMsg "Info - Powershell $version is installed in target VM"
			writeCustomizedMsg "Info - Powershell Remoting is enabled in target VM"
			return $true
		} else {
			writeCustomizedMsg "Info - Powershell Remoting is NOT enabled in target VM"
			return $false
		}
	} -name checkPsRemote
	
	$vm | add-member -MemberType ScriptMethod -Value { ##enablePsRemote
		if ($this.checkPsRemote()) {
			return
		}
		$this.installPs()
		$cmd = @'
if([environment]::OSVersion.version.Major -lt 6) { 
$regkey = "HKLM:\system\currentcontrolset\control\lsa"
set-itemproperty -path $regkey -name forceguest -value 0
return } 
if(1,3,4,5 -contains (Get-WmiObject win32_computersystem).DomainRole) { return } 
$networkListManager = [Activator]::CreateInstance([Type]::GetTypeFromCLSID([Guid]"{DCB00C01-570F-4A9B-8D69-199FDBA5723B}")) 
$connections = $networkListManager.GetNetworkConnections() 
$connections | % {$_.GetNetwork().SetCategory(1)}
'@
		$this.runScript($cmd,"Powershell")
		$cmd = @'
try {enable-psremoting -force -ea SilentlyContinue
Set-Item WSMan:\localhost\Shell\MaxMemoryPerShellMB 1024 -wa 0 -ea SilentlyContinue}
catch { write-output "Error occurred to enable-psremoting"}
sc.exe config winrm start= auto | out-null
netsh advfirewall firewall set rule name="Windows Remote Management (HTTP-In)" new profile=any remoteip=any
'@
		$this.runScript($cmd,"Powershell")
	} -name enablePsRemote
	
	$vm | add-member -MemberType ScriptMethod -Value { ##enableCredSSP
		$cmd = @'
try {Enable-WSManCredSSP -role server -force -ea SilentlyContinue | out-null}
catch { echo "CredSSP is not supported on Windows XP or 2003"}
'@
		$this.runScript($cmd,"Powershell")
	} -name enableCredSSP
	
	$vm | add-member -MemberType ScriptMethod -Value { ##renewIp
		$cmd = @'
$ip = ipconfig | select-string ("ipv4 address","ip address")
$ip = $ip.line.split(": ")[-1]
if ($ip.startswith("169.254")){
$ip = ipconfig /renew
$ip = $ip | select-string ("ipv4 address","ip address")
$ip = $ip.line.split(": ")[-1]
}
$ip
'@	
		$ip = $this.runScript($cmd,"Powershell")
		if ($ip.startswith("169.254")) {
			writeCustomizedMsg "Fail - renew VM IP $ip"
			[Environment]::exit("0")
		} else {
			writeCustomizedMsg "Success - renew VM IP $ip"
			return $ip.trim()
		}	
	} -name renewIp
	
	return $vm
}

function newVm {
	Param($server,$name,$user,$password)

	try {
		$vivm = get-vm -Name $name -Server $server.viserver -wa 0 -EA stop
	} catch {
		writeCustomizedMsg "Fail - get VM $name"
		writeStderr
		[Environment]::exit("0")
	}

	$vm = New-Object PSObject -Property @{
		server = $server
		name = $name
		user = $user
		password = $password
		vivm = $vivm
	}
	
	$vm | add-member -MemberType ScriptMethod -value { ##start
		$this.vivm = get-vm $this.name -server $this.server.viserver
		if ($this.vivm.powerstate -ne "PoweredOn"){
			$task = Start-VM -VM $this.vivm -confirm:$false
			if ($task.powerstate -eq "PoweredOn") {
				writeCustomizedMsg "Success - start VM $($this.name)"
			} else {
				writeCustomizedMsg "Fail - start VM $($this.name)"
				[Environment]::exit("0")
			}
		} else {
			writeCustomizedMsg "Warning - VM $($this.name) is already powered on"
		}
		$this.waitForTools()
	} -name start
	
	$vm | Add-Member -MemberType ScriptMethod -Value { ##stop
		#$this.waitForTools()
		$i = 0
		do {
			$this.vivm = get-vm $this.name -server $this.server.viserver
			if ($this.vivm.powerstate -eq "PoweredOff"){
				writeCustomizedMsg "Info - VM $($this.name) is powered off"
				# $taskList = get-task -server $this.server.viserver | where {($_.objectid -eq $this.vivm.id) -and ($_.name -eq "ShutdownGuest")}
				# foreach($task in $taskList) {
					# writeCustomizedMsg "$($task.state.toString()) - shutdown VM $($this.name) triggered at $($task.starttime)"
				# }
				return
			} else {
				Shutdown-VMGuest -vm $this.vivm -server $this.server.viserver -confirm:$false | out-null
				start-sleep 30
				$i++
			}			
		} while ($i -lt 10)
		$null = stop-vm -vm $this.vivm -confirm:$false
		writeCustomizedMsg "Warning - VM $($this.name) is killed forcely"
	} -Name stop
	
	$vm | Add-Member -MemberType ScriptMethod -Value { ##suspend
		$this.vivm = get-vm $this.name -server $this.server.viserver
		try {
			$null = Suspend-VM -vm $this.vivm -confirm:$false -EA stop
		} catch {
			writeCustomizedMsg "Fail - suspend VM $($this.name)"
			writeStderr
			[Environment]::exit("0")
		}
		writeCustomizedMsg "Success - suspend VM $($this.name)"
	} -Name suspend
	
	$vm | Add-Member -MemberType ScriptMethod -Value { ##restart
		#if ($this.rpc.session.state -match "Opened") {
		#	$this.rpc.restart()
		#	return
		#}
		$this.waitForTools()
		$this.vivm = get-vm $this.name -server $this.server.viserver
		try {
			$null = Restart-VMGuest -vm $this.vivm -confirm:$false -EA stop
		} catch {
			writeCustomizedMsg "Fail - restart VM $($this.name)"
			writeStderr
			[Environment]::exit("0")
		}
		writeCustomizedMsg "Success - restart VM $($this.name)"
		$this.waitForTools()
	} -Name restart
	
	$vm | add-member -MemberType ScriptMethod -value { ##waitForTools
		param($delay=10,$timeout=300)
		$this.vivm = get-vm $this.name -server $this.server.viserver
		if ($this.vivm.powerstate -eq "PoweredOff"){$this.start()}
		$i = 0
		do {
			$vm_view = Get-VM $this.vivm -server $this.server.viserver | get-view
			$status = $vm_view.Guest.ToolsRunningStatus
			if ($status -ne "guestToolsRunning") {
				start-sleep $delay
			}
			$i++
		} while (($status -ne "guestToolsRunning") -and ($i * $delay -lt $timeout))
		#Start-Sleep 10
		if ($status -ne "guestToolsRunning")
		{
			writeCustomizedMsg "Fail - VMware Tools is not running in the VM"
			[Environment]::exit("0")
		} # else {
			# $gosName = (Get-VMGuest $this.vivm).OSFullName
			# if ($gosName -match "Windows") {
				# $i = 0;
				# while ($true){
					# $output = Invoke-VMScript -ScriptText "echo test" -ScriptType "Bat" -VM $this.vivm `
						# -GuestUser $this.user -GuestPassword $this.password -confirm:$false -EA SilentlyContinue
					# if ($output -match "test") {
						# writeCustomizedMsg "Success - run test script through VMware Tools"
						# return
					# } else {
						# start-sleep 10
						# $i++
					# }
					# if ($i -gt 30) {
						# writeCustomizedMsg "Fail - run test script through VMware Tools"
						# [Environment]::exit("0")
					# }
				# }
			# }
		# }
	} -name waitForTools
	
	$vm | add-member -MemberType ScriptMethod -Value { ##runScript
		Param($script, $type, $runAsync=$false)
		# if ($this.rpc.session.state -match "Opened") {
			# $sb = [scriptblock]::Create($script)
			# $output = invoke-command $sb -session $this.rpc.session
			# return $output
		# }
		$this.waitForTools()
		try {
			$output = Invoke-VMScript -ScriptText $script -ScriptType $type -VM $this.vivm `
				-Server $this.server.viserver -HostUser $this.server.admin -HostPassword $this.server.passwd -toolswaitsecs 60 `
				-GuestUser $this.user -GuestPassword $this.password -confirm:$false -EA Stop
		} catch {
			writeCustomizedMsg "Fail - run VM script $script"
			writeStderr
			[Environment]::exit("0")
		}	
		return $output.scriptoutput
	} -name runScript
	
	$vm | add-member -MemberType ScriptMethod -Value { ##runScriptAsync
		Param($script, $type)
		$this.waitForTools()
		try {
			$output = Invoke-VMScript -ScriptText $script -ScriptType $type -VM $this.vivm `
				-GuestUser $this.user -GuestPassword $this.password -confirm:$false -RunAsync -EA Stop
		} catch {
			writeCustomizedMsg "Fail - run VM script $script"
			writeStderr
			[Environment]::exit("0")
		}
		writeCustomizedMsg "Success - run VM script $script"
		return $output.scriptoutput
	} -name runScriptAsync
	
	$vm | add-member -MemberType ScriptMethod -Value { ##copyFileToVm
		Param($file,$dst)
		$file = resolve-path $file
		if ($dst.endswith("\")) {
			#$dstFile = (split-path $dst) + "\" + (get-childitem $file).Name
			$dstFile = $dst + (get-childitem $file).Name
		} else {
			$dstFile = $dst
		}
		# if ($this.rpc.session.state -match "Opened") {
			# $this.rpc.sendFile($file, $dstFile)
			# return
		# }
		$this.waitForTools()
		try {
			copy-VMGuestFile -source $file -destination $dst -vm $this.vivm `
				-GuestUser $this.user -GuestPassword $this.password -force `
				-LocalToGuest -confirm:$false -ToolsWaitSecs 120 -EA Stop | out-null
				#-Server $this.server.viserver -HostUser $this.server.admin -HostPassword $this.server.passwd `
		} catch {
			writeCustomizedMsg "Fail - copy file to VM"
			writeStderr
			[Environment]::exit("0")
		}	
		writeCustomizedMsg "Success - copy file to VM"
	} -name copyFileToVm
	
	$vm | add-member -MemberType ScriptMethod -Value { ##restoreSnapshot
		Param($snapshot)		
		$ss = get-snapshot -vm $this.vivm -Server $this.server.viserver | where{$_.name -eq "$snapshot"}
		if (!$ss) {
			writeCustomizedMsg("Fail - find snapshot $snapshot")
			[Environment]::exit("0")
		} elseif ($ss.count -ne $null) {
			$ss = $ss[-1]
		}
		set-VM -vm $this.vivm -snapshot $ss -confirm:$false -Server $this.server.viserver | out-null
		$ss = get-snapshot -vm $this.vivm -Server $this.server.viserver | where{$_.name -eq "$snapshot"} 
		if ($ss.iscurrent -eq $true) {
			writeCustomizedMsg("Success - restore snapshot $snapshot")
			#$this.rpc = $null
		} else {
			writeCustomizedMsg("Fail - restore snapshot $snapshot")
			[Environment]::exit("0")
		}
	} -name restoreSnapshot
	
	$vm | add-member -MemberType ScriptMethod -Value { ##takeSnapshot
		Param($name,$description)

		$ss = get-snapshot -name $name -vm $this.vivm -Server $this.server.viserver
		
		if ($ss) {
			writeCustomizedMsg("Warning - snapshot $name already exists, deleting it...")
			remove-Snapshot -snapshot $ss -Confirm:$false
			
			$ss = get-snapshot -name $name -vm $this.vivm -Server $this.server.viserver
			if ($ss) {
				writeCustomizedMsg("Fail - delelet Snapshot $name")
				exit
			} else {
				writeCustomizedMsg("Success - delelet Snapshot $name")
			}
		}
			
		if (!$description) {$description = "Created by Web Commander on " + (get-date)}
		$newSnapshot = new-snapshot -Name $name -Description $description -VM $this.vivm -Server $this.server.viserver -Confirm:$false
		if ($newSnapshot -ne $null) {
			writeCustomizedMsg("Success - create snapshot $name")
		} else {
			writeCustomizedMsg("Fail - create snapshot $name")
		}
	} -name takeSnapshot
	
	$vm | add-member -MemberType ScriptMethod -Value { ##removeSnapshot
		Param($snapshot)
		
		$ss = get-snapshot -vm $this.vivm -Server $this.server.viserver | where{$_.name -eq "$snapshot"}
		if (!$ss) {
			writeCustomizedMsg("Fail - find snapshot $snapshot")
			[Environment]::exit("0")
		} elseif ($ss.count -gt 1) {
			writeCustomizedMsg("Warn - find more than 1 snapshots named $snapshot")
			writeCustomizedMsg("Fail - delete snapshot $snapshot")
			[Environment]::exit("0")
		}
		
		try {
			get-snapshot -vm $this.vivm -name $snapshot -ea stop | remove-snapshot -confirm:$false -ea stop
		} catch {
			writeCustomizedMsg "Fail - delete snapshot $snapshot"
			writeStderr
			[Environment]::exit("0")
		}
		writeCustomizedMsg "Success - delete snapshot $snapshot"	
	} -name removeSnapshot
	
	$vm | add-member -MemberType ScriptMethod -Value { ##getIpv4
		$ip = (Get-VMGuest $this.vivm).IPAddress[0]
		$i = 0
		while ((!$ip -or ($ip -match [regex]"^169.254")) -and ($i -lt 6)) {
			start-sleep 10
			$i++
			$ip = (Get-VMGuest $this.vivm).IPAddress[0]
		}
		if (!$ip) {
			writeCustomizedMsg "Fail - get VM IP address"
			[Environment]::exit("0")
		} elseif ($ip -match [regex]"^169.254") {
			$this.runScript("ipconfig /renew","Bat")
			start-sleep 20
			$ip = (Get-VMGuest $this.vivm).IPAddress[0]
		} else {
			return $ip
		}
	} -name getIPv4

	$vm | add-member -MemberType ScriptMethod -Value { ##getIpv6
		return (Get-VMGuest $this.vivm).IPAddress[1]
	} -name getIPv6
	
	$vm | add-member -MemberType ScriptMethod -Value { ##videoRamAuto
		$vidDev = $this.vivm.ExtensionData.Config.Hardware.Device | where {$_.DeviceInfo.Label -like "Video*"}
    	$spec = New-Object VMware.Vim.VirtualMachineConfigSpec       
		$dev = New-Object VMware.Vim.VirtualDeviceConfigSpec        
		$dev.operation = "edit"        
		$vidDev.UseAutoDetect = $true        
		$dev.Device += $vidDev        
		$spec.DeviceChange += $dev        
    	$this.vivm.ExtensionData.ReconfigVM($spec)
	} -name videoRamAuto

	$vm | add-member -MemberType ScriptMethod -Value { ##getVmHost
		return (Get-VMHost -Server  $this.server.viserver -VM $this.name).name
	} -name getVmHost
	
	$vm | add-member -MemberType ScriptMethod -Value { ##linkClone
		Param($snapshot, $namePrefix, $number)	

		$sourceVM = $this.vivm | Get-View  
		$cloneFolder = $sourceVM.parent  
		$cloneSpec = new-object Vmware.Vim.VirtualMachineCloneSpec
		
		if ($snapshot) {
			$ss = get-snapshot -vm $this.vivm -name $snapshot -Server $this.server.viserver -ea silentlycontinue
			if(!$ss){
				write-output "Fail - find snapshot $snapshot"
				[Environment]::exit("0")
			}
			$cloneSpec.Snapshot = ($ss | get-view).moref
		} else { 
			$cloneSpec.Snapshot = $sourceVM.Snapshot.CurrentSnapshot   
		}
		
		$cloneSpec.Location = new-object Vmware.Vim.VirtualMachineRelocateSpec  
		$cloneSpec.Location.DiskMoveType = [Vmware.Vim.VirtualMachineRelocateDiskMoveOptions]::createNewChildDiskBacking
		if (!$number) {
			$cloneName = $namePrefix
			$sourceVM.CloneVM_Task( $cloneFolder, $cloneName, $cloneSpec )
		} else {
			$number = [int]$number
			for ($i = 1; $i -le $number; $i++) {
				$cloneName = $namePrefix + "-" + $i
				$sourceVM.CloneVM_Task( $cloneFolder, $cloneName, $cloneSpec ) | out-null
				write-output "$cloneName is created`n"
			}
		}
	} -name linkClone
	
	$vm | add-member -MemberType ScriptMethod -Value { ##getVmx
		$Destination = "..\www\download\" + $this.server.address + "_" + $this.name + ".vmx" 
		$vmxfile = $this.vivm.Extensiondata.Summary.Config.VmpathName
		$dsname = $vmxfile.split(" ")[0].TrimStart("[").TrimEnd("]")
		$ds = Get-Datastore -server $this.server.viserver -Name $dsname
		New-PSDrive -Name ds -PSProvider VimDatastore -Root '/' -Location $ds | out-null
		Copy-DatastoreItem -Item "ds:\$($vmxfile.split(']')[1].TrimStart(' '))" -Destination $Destination
		$vmx = get-content $Destination
		writeStdout $vmx
		Remove-PSDrive -Name ds
	} -name getVmx
	
	$vm | add-member -MemberType ScriptMethod -Value { ##setVmx
		param($source) 
		$vmxfile = $this.vivm.Extensiondata.Summary.Config.VmpathName
		$dsname = $vmxfile.split(" ")[0].TrimStart("[").TrimEnd("]")
		$ds = Get-Datastore -server $this.server.viserver -Name $dsname
		New-PSDrive -Name ds -PSProvider VimDatastore -Root '/' -Location $ds | out-null
		Copy-DatastoreItem $source "ds:\$($vmxfile.split(']')[1].TrimStart(' '))" -Force
		Remove-PSDrive -Name ds
	} -name setVmx
	
	return $vm
}

function newRemoteWinBroker {
	Param($ip,$admin,$password,$isVm=$false)

	$broker = newRemoteWin $ip $admin $password $isVm
	
	$broker | add-member -MemberType ScriptMethod -Value { ##initialize
		$msg = "initialize broker"
		$argList = @()
		$cmd = {
			Add-PSSnapin vm* -ea SilentlyContinue
			$test = get-PSSnapin vmware.view.broker -ea silentlyContinue
			if (!$test) {
				$installUtil = @(gci 'c:\windows\Microsoft.Net\Framework64\' -recurse -filter 'installUtil.exe')
				if(!$installUtil){throw 'cannot find installUtil.exe'}
				#& 'c:\windows\Microsoft.Net\Framework64\v2.0.50727\installUtil.exe' 'c:\Program Files\vmware\vmware view\server\bin\powershellservicecmdlets.dll'
				& $installUtil[-1].pspath 'c:\Program Files\vmware\vmware view\server\bin\powershellservicecmdlets.dll'
				Import-Module servermanager 
				Add-WindowsFeature Telnet-Server 
				Set-Service TlntSvr -StartupType Automatic -Status Running 
				tlntadmn config maxconn = 100 
				tlntadmn config timeout = 24:00:00 
				Add-PSSnapin vm* -ea Stop
			}
			cd 'c:\program files\vmware\vmware view\server\tools\bin'
			if (!(test-path .\viewapiutil.cmd) -and (test-path .\lmvutil.cmd)) {
				(get-content .\lmvutil.cmd) -replace '.LmvUtil', '.ViewApiUtil' | set-content .\viewapiutil.cmd
			}
		}
		$this.executePsRemote($cmd, $argList, $msg)	
	} -name initialize
	
	$broker | add-member -MemberType ScriptMethod -Value { ##addLicense
		Param($license)
		$msg = "add broker license"
		$argList = @($license)
		$cmd = {
			Add-PSSnapin vm*
			set-license -k $args[0]
		}
		$this.executePsRemote($cmd, $argList, $msg)
	} -name addLicense
	
	$broker | add-member -MemberType ScriptMethod -Value { ##addVc
		Param($vcAddress, $vcUser, $vcPassword, $useComposer)
		$msg = "add vc"
		$argList = @($vcAddress,$vcUser,$vcPassword,$useComposer)
		$cmd = {
			add-pssnapin vm*
			$cmd = get-command add-viewvcAcceptAnyCert -ea silentlycontinue
			if ($cmd) {
				add-viewvcAcceptAnyCert -servername $args[0] -user $args[1] -password $args[2] -useComposer $args[3] -ea Stop	
			} else {
				add-viewvc -servername $args[0] -user $args[1] -password $args[2] -useComposer $args[3] -ea Stop
			}
		}
		$this.executePsRemote($cmd, $argList, $msg)
	} -name addVc
	
	$broker | add-member -MemberType ScriptMethod -Value { ##addComposer
		Param($vcAddress, $composerAddress, $composerUser, $composerPassword, $port)
		$msg = "add standalone composer"
		$argList = @($vcAddress,$port,$composerAddress,$composerUser,$composerPassword)
		$cmd = {
			add-pssnapin vm* 
			update-viewvcAcceptAnyCert -servername $args[0] -useComposer $true -ComposerPort $args[1] `
				-ComposerServerName $args[2] -ComposerUser $args[3] -ComposerPassword $args[4] -ea Stop
		}		
		$this.executePsRemote($cmd, $argList, $msg)
	} -name addComposer
	
	$broker | add-member -MemberType ScriptMethod -Value { ##addComposerDomain
		Param($vcAddress, $domainName, $domainUser, $domainPassword)
		$msg = "add composer domain $domainName"
		$vcId = $this.getVcId($vcAddress)
		$argList = @($vcId,$domainName,$domainUser,$domainPassword)
		$cmd = {
			add-pssnapin vm*
			add-ComposerDomain -vc_id $args[0] -domain $args[1] -username $args[2] -password $args[3] -ea Stop
		}
		$this.executePsRemote($cmd, $argList, $msg)
	} -name addComposerDomain
	
	$broker | Add-Member -MemberType ScriptMethod -Value { ##addManualPool
		Param($vc,$vmNameList,$pooId,$type)
		$msg = "add pool to broker"
		$vmId = @()
		foreach ($vmName in $vmNameList) {
			$vmId += (get-vm -name $vmName -server $vc.viserver).id
		}
		$vmIdList = $vmId -join ";"
		$vcId = $this.getVcId($vc.address)
		$argList = @($poolId,$vcId,$vmIdList,$type)
		$cmd = {
			Add-PSSnapin vm*
			Add-manualpool -pool_id $args[0] -vc_id $args[1] -vm_id_list $args[2] -Persistence $args[3] -ea Stop
		}
		$this.executePsRemote($cmd, $argList, $msg)
	} -Name addManualPool
	
	$broker | Add-Member -MemberType ScriptMethod -Value { ##addLinkedClonePool	
		Param($vcAddress, $composerDomainName, $poolId, $namePrefix, $parentVmPath, $parentSnapshotPath, $vmFolderPath, 
			$resourcePoolPath, $datastoreSpecs, $dataDiskLetter, $dataDiskSize, $tempDiskSize, $min, $max, $poolType)
		$msg = "add pool to broker"
		$cmd = "
			Add-PSSnapin vm*	
			Get-ViewVC -serverName $vcAddress | Get-ComposerDomain -domain $composerDomainName | ``
				Add-AutomaticLinkedCLonePool -pool_id $poolId ``
					-namePrefix $namePrefix ``
					-parentVMPath $parentVmPath ``
					-parentSnapshotPath $parentSnapshotPath ``
					-vmFolderPath $vmFolderPath ``
					-resourcePoolPath $resourcePoolPath ``
					-datastoreSpecs '$datastoreSpecs' ``
					-dataDiskLetter '$dataDiskLetter' ``
					-dataDiskSize $dataDiskSize ``
					-tempDiskSize $tempDiskSize ``
					-minimumCount $min ``
					-maximumCount $max ``
					-headroomCount $max ``
					-persistence $poolType ``
					-powerPolicy 'AlwaysOn' ``
					-ea Stop
				Update-AutomaticLinkedClonePool -pool_id $poolId -suspendProvisioningOnError `$false -ea stop
		"
		$this.executePsTxtRemote($cmd, $msg)
	} -Name addLinkedClonePool
	
	$broker | Add-Member -MemberType ScriptMethod -Value { ##rebalanceLinkedClonePool	
		Param($poolId)
		$msg = "rebalance linked clone pool"
		$cmd = "
			Add-PSSnapin vm*	
			Get-DesktopVM -pool_id $poolId | Send-LinkedCloneRebalance -schedule (get-date).addMinutes(3) -forceLogoff `$true -stopOnError `$false
		"
		$this.executePsTxtRemote($cmd, $msg)
	} -Name rebalanceLinkedClonePool
	
	$broker | Add-Member -MemberType ScriptMethod -Value { ##refreshLinkedClonePool	
		Param($poolId)
		$msg = "refresh linked clone pool"
		$cmd = "
			Add-PSSnapin vm*	
			Get-DesktopVM -pool_id $poolId | Send-LinkedCloneRefresh -schedule (get-date).addMinutes(3) -forceLogoff `$true -stopOnError `$false
		"
		$this.executePsTxtRemote($cmd, $msg)
	} -Name refreshLinkedClonePool
	
	$broker | Add-Member -MemberType ScriptMethod -Value { ##recomposeLinkedClonePool	
		Param($poolId, $parentVmPath, $parentSnapshotPath)
		$msg = "recompose linked clone pool"
		$cmd = "
			Add-PSSnapin vm*	
			Get-DesktopVM -pool_id $poolId | Send-LinkedCloneRecompose -schedule (get-date).addMinutes(3) -forceLogoff `$true -stopOnError `$false ``
				-parentVMPath '$parentVmPath' -parentSnapshotPath '$parentSnapshotPath'
		"
		$this.executePsTxtRemote($cmd, $msg)
	} -Name recomposeLinkedClonePool
	
	$broker | Add-Member -MemberType ScriptMethod -Value { ##sendSessionLogoff	
		Param($poolId)
		$msg = "send session logoff to pool"
		$cmd = "
			Add-PSSnapin vm*	
			Get-RemoteSession -pool_id $poolId | Send-SessionLogoff
		"
		$this.executePsTxtRemote($cmd, $msg)
	} -Name sendSessionLogoff

	$broker | Add-Member -MemberType ScriptMethod -Value { ##addTsPool
		Param($poolId)
		$msg = "add pool to broker"
		$argList = @($poolId)
		$cmd = {
			Add-PSSnapin vm* 
			get-terminalserver|add-terminalserverpool -pool_id $args[0]
		}
		$this.executePsRemote($cmd, $argList, $msg)
	} -Name addTsPool
	
	$broker | Add-Member -MemberType ScriptMethod -Value { ##entitlePool
		Param($poolId,$user,$domain)
		$msg = "entitle pool"
		$argList = @($user, $domain, $poolId)
		$cmd = {
			Add-PSSnapin vm*
			$name = $args[0]
			$domain = $args[1]
			$poolId = $args[2]
			$user = get-user -name $name -domain $domain | ?{$_.displayName -like "$domain*\$name"}
			add-poolEntitlement -pool_id $poolId -sid $user.sid -ea Stop
		}
		$this.executePsRemote($cmd, $argList, $msg)
	} -Name entitlePool
	
	$broker | Add-Member -MemberType ScriptMethod -Value { ##removePool
		Param($pool_id, $rmFromDisk)
		$msg = "remove pool $pool_id"
		$argList = @($poolId, $rmFromDisk)
		$cmd = {
			Add-PSSnapin vm*
			remove-pool -pool_id $args[0] -DeleteFromDisk $args[1] -terminateSession $true -ea Stop
		}
		$this.executePsRemote($cmd, $argList, $msg)
		# $msg = "wait pool removal to complete"
		# $argList = @($poolId)
		# $cmd = {
			# Add-PSSnapin vm*
			# $flag = $false
			# while ($flag -eq $false) {
				# $pool = get-pool -pool_id $args[0] -ea silentlyContinue
				# if ($pool) {
					# start-sleep 60
				# } else {
					# $flag = $true
				# }		
			# }
		# }
		# $this.executePsRemote($cmd, $argList, $msg, 5400)
	} -Name removePool
	
	$broker | Add-Member -MemberType ScriptMethod -Value { ##setDirectConnect
		Param($switch)
		$msg = "set direct connection"
		$argList = @($switch)
		$cmd = {
			Add-PSSnapin vm*
			get-connectionbroker | update-connectionbroker -directconnect $args[0] -ea Stop
		}
		$this.executePsRemote($cmd, $argList, $msg)
	} -Name setDirectConnect
	
	$broker | Add-Member -MemberType ScriptMethod -Value { ##setDirectPCoIP
		Param($switch)
		$msg = "set direct PCoIP"
		$argList = @($switch)
		$cmd = {
			Add-PSSnapin vm*	
			get-connectionbroker | update-connectionbroker -directPCoIP $args[0] -ea Stop
		}
		$this.executePsRemote($cmd, $argList, $msg)
	} -Name setDirectPCoIP
	
	$broker | Add-Member -MemberType ScriptMethod -Value { ##setHtmlAccess
		Param($poolId,$switch)
		$msg = "set HTML Access"
		$argList = @($poolId,$switch)
		$cmd = {
			$serverObject = [ADSI]("LDAP://localhost:389/cn=" + $args[0] + ",ou=applications,dc=vdi,dc=vmware,dc=int")
			# $spl = $serverObject.get("pae-ServerProtocolLevel")
			if ($args[1] -eq "true") {
				# $spl = @($spl | ?{$_ -ne "BLAST"}) + "BLAST"
				$spl = @("BLAST","PCOIP","RDP")
			} else {
				# $spl = $spl | ?{$_ -ne "BLAST"}
				$spl = @("PCOIP","RDP")
			}
			$serverObject.putex(2,"pae-ServerProtocolLevel",$spl)
			$serverObject.setinfo()
		}
		$this.executePsRemote($cmd, $argList, $msg)
	} -Name setHtmlAccess
	
	$broker | Add-Member -MemberType ScriptMethod -Value { ##setFarmHtmlAccess
		Param($farmId,$switch)
		$msg = "set HTML Access"
		$argList = @($farmId,$switch)
		$cmd = {
			$serverObject = [ADSI]("LDAP://localhost:389/cn=" + $args[0] + ",ou=Server Groups,dc=vdi,dc=vmware,dc=int")
			if ($args[1] -eq "true") {
				$spl = @("BLAST","PCOIP","RDP")
			} else {
				$spl = @("PCOIP","RDP")
			}
			$serverObject.putex(2,"pae-ServerProtocolLevel",$spl)
			$serverObject.setinfo()
		}
		$this.executePsRemote($cmd, $argList, $msg)
	} -Name setFarmHtmlAccess
	
	$broker | Add-Member -MemberType ScriptMethod -Value { ##setPoolAutoRecovery
		Param($poolId,$action)
		$msg = "set pool auto-recovery $action"
		$argList = @($poolId,$action)
		$cmd = {
			$pool = [ADSI]("LDAP://localhost:389/cn=" + $args[0] + ",ou=Server Groups,dc=vdi,dc=vmware,dc=int")
			if ($args[1] -eq "enable") {
				$pool.put("pae-RecoveryDisabled", "0")
			} else {
				$pool.put("pae-RecoveryDisabled", "1")
			}
			$pool.setinfo()
		}
		$this.executePsRemote($cmd, $argList, $msg)
	} -Name setPoolAutoRecovery
	
	$broker | Add-Member -MemberType ScriptMethod -Value { ##setMmrPolicy
		Param($action)
		$msg = "set MMR policy $action"
		$argList = @($action)
		$cmd = {
			$pool = [ADSI]("LDAP://localhost:389/cn=0,ou=VDM,ou=Policies,dc=vdi,dc=vmware,dc=int")
			if ($args[0] -eq "enable") {
				$pool.put("pae-AllowMMR", "1")
			} else {
				$pool.put("pae-AllowMMR", "0")
			}
			$pool.setinfo()
		}
		$this.executePsRemote($cmd, $argList, $msg)
	} -Name setMmrPolicy
	
	$broker | Add-Member -MemberType ScriptMethod -Value { ##addRdsDesktopPool
		Param($farmId,$poolId)
		$msg = "create desktop pool"
		$argList = @($farmId,$poolId)
		$cmd = {
			$farmDn = "cn=" + $args[0] + ",ou=Server Groups,dc=vdi,dc=vmware,dc=int"
			$appObject = [ADSI]"LDAP://localhost:389/ou=applications,dc=vdi,dc=vmware,dc=int"
			$desktop = $appObject.create("pae-DesktopApplication","CN=" + $args[1])
			$desktop.put("pae-Servers", $farmDn)
			$desktop.put("pae-DisplayName", $args[1])
			$desktop.put("pae-Icon", "/thinapp/icons/desktop.gif")
			$desktop.put("pae-URL", "\")
			$desktop.put("pae-Disabled", "0")
			$desktop.put("pae-FlashQuality", "0")
			$desktop.put("pae-FlashThrottling", "0")
			$desktop.setinfo()
		}
		$this.executePsRemote($cmd, $argList, $msg)
	} -Name addRdsDesktopPool
	
	$broker | Add-Member -MemberType ScriptMethod -Value { ##addRdsAppPool
		Param($farmId,$poolId,$execPath)
		$msg = "create application pool"
		$argList = @($farmId,$poolId,$execPath)
		$cmd = {
			$farmDn = "cn=" + $args[0] + ",ou=Server Groups,dc=vdi,dc=vmware,dc=int"
			$appObject = [ADSI]"LDAP://localhost:389/ou=applications,dc=vdi,dc=vmware,dc=int"
			$desktop = $appObject.create("pae-RDSApplication","CN=" + $args[1])
			$desktop.put("pae-Servers", $farmDn)
			$desktop.put("pae-DisplayName", $args[1])
			#$desktop.put("pae-Icon", "/thinapp/icons/desktop.gif")
			#$desktop.put("pae-URL", "\")
			$desktop.put("pae-Disabled", "0")
			#$desktop.put("pae-AdminFolderDN", "OU=Groups,DC=vdi,DC=vmware,DC=int")
			$desktop.put("pae-ApplicationExecutablePath", $args[2])
			$desktop.setinfo()
		}
		$this.executePsRemote($cmd, $argList, $msg)
	} -Name addRdsAppPool
	
	$broker | Add-Member -MemberType ScriptMethod -Value { ##addFarm
		Param($farmId)
		$msg = "add farm"
		$argList = @($farmId)
		$cmd = {
			$appObject = [ADSI]"LDAP://localhost:389/ou=Server Groups,dc=vdi,dc=vmware,dc=int"
			$farm = $appObject.create("pae-ServerPool","CN=" + $args[0])
			$farm.put("pae-ServerPoolType", "8")
			$farm.put("pae-ServerProtocolAllowOverride", "1")
			$farm.put("pae-OptLogoffEmptySessionOnTimeout", "0")
			#$farm.put("pae-ServerProtocolLevel", "RDP")
			#$farm.put("pae-ServerProtocolLevel", "PCOIP")
			$farm.putex(3,"pae-ServerProtocolLevel",@("PCOIP","RDP"))
			$farm.put("pae-Disabled", "0")
			$farm.put("pae-OptDisconnectLimitTimeout", "0")
			$farm.put("pae-DisplayName", $args[0])
			$farm.put("pae-OptEmptyLimitTimeout", "1")
			$farm.put("pae-ServerProtocolDefault", "PCOIP")
			$farm.setinfo()
		}
		$this.executePsRemote($cmd, $argList, $msg)
	} -Name addFarm
	
	$broker | Add-Member -MemberType ScriptMethod -Value { ##addRdsServerToFarm
		Param($farmId,$rdsServerAddress)
		$msg = "add RDS server to farm"
		$argList = @($farmId, $rdsServerAddress)
		$cmd = {
			$Searcher = New-Object DirectoryServices.DirectorySearcher
			$Searcher.Filter = '(&(ipHostNumber=' + $args[1] + '))'
			$Searcher.SearchRoot = 'LDAP://localhost:389/OU=servers,DC=vdi,DC=VMware,DC=int'
			$rds = [ADSI]$Searcher.FindAll()[0].path
			$farm = [ADSI]("LDAP://localhost:389/cn=" + $args[0] + ",ou=Server Groups,dc=vdi,dc=vmware,dc=int")
			$farm.putex(3,"pae-MemberDN",@($rds.distinguishedName))
			$farm.setinfo()
		}
		$this.executePsRemote($cmd, $argList, $msg)
	} -Name addRdsServerToFarm
	
	$broker | Add-Member -MemberType ScriptMethod -Value { ##removeRdsServerFromFarm
		Param($farmId,$rdsServerAddress)
		$msg = "remove RDS server from farm"
		$argList = @($farmId, $rdsServerAddress)
		$cmd = {
			$Searcher = New-Object DirectoryServices.DirectorySearcher
			$Searcher.Filter = '(&(ipHostNumber=' + $args[1] + '))'
			$Searcher.SearchRoot = 'LDAP://localhost:389/OU=servers,DC=vdi,DC=VMware,DC=int'
			$rds = [ADSI]$Searcher.FindAll()[0].path
			$farm = [ADSI]("LDAP://localhost:389/cn=" + $args[0] + ",ou=Server Groups,dc=vdi,dc=vmware,dc=int")
			$farm.putex(4,"pae-MemberDN",@($rds.distinguishedName))
			$farm.setinfo()
		}
		$this.executePsRemote($cmd, $argList, $msg)
	} -Name removeRdsServerFromFarm
	
	$broker | Add-Member -MemberType ScriptMethod -Value { ##setPoolName
		Param($poolId, $poolName)
		$msg = "set pool display name"
		$argList = @($poolId, $poolName)
		$cmd = {
			$pool = [ADSI]("LDAP://localhost:389/cn=" + $args[0] + ",ou=applications,dc=vdi,dc=vmware,dc=int")
			$pool.put("pae-DisplayName", $args[1])
			$pool.setinfo()
		}
		$this.executePsRemote($cmd, $argList, $msg)
	} -Name setPoolName
	
	$broker | Add-Member -MemberType ScriptMethod -Value { ##setPoolId
		Param($poolId, $newId)
		$msg = "set pool ID"
		$argList = @($poolId, $newId)
		$cmd = {
			$app = [ADSI]"LDAP://localhost:389/ou=applications,dc=vdi,dc=vmware,dc=int"
			$app.movehere("LDAP://localhost:389/cn=" + $args[0] + ",ou=applications,dc=vdi,dc=vmware,dc=int", "CN=" + $args[1])
		}
		$this.executePsRemote($cmd, $argList, $msg)
	} -Name setPoolId
	
	$broker | Add-Member -MemberType ScriptMethod -Value { ##deleteRdsAppPool
		Param($poolId)
		$msg = "delete application pool"
		$argList = @($poolId)
		$cmd = {
			$appObject = [ADSI]"LDAP://localhost:389/ou=applications,dc=vdi,dc=vmware,dc=int"
			$appObject.delete("pae-RDSApplication","CN=" + $args[0])
		}
		$this.executePsRemote($cmd, $argList, $msg)
	} -Name deleteRdsAppPool
	
	$broker | Add-Member -MemberType ScriptMethod -Value { ##deleteRdsDesktopPool
		Param($poolId)
		$msg = "delete desktop pool"
		$argList = @($poolId)
		$cmd = {
			$appObject = [ADSI]"LDAP://localhost:389/ou=applications,dc=vdi,dc=vmware,dc=int"
			$appObject.delete("pae-DesktopApplication","CN=" + $args[0])
		}
		$this.executePsRemote($cmd, $argList, $msg)
	} -Name deleteRdsDesktopPool
	
	$broker | Add-Member -MemberType ScriptMethod -Value { ##entitleRdsAppPool
		Param($userName,$domainName,$poolId)
		$msg = "entitle application pool"
		$argList = @($userName, $domainName, $poolId)
		$cmd = {
			Add-PSSnapin vm*
			$name = $args[0]
			$domain = $args[1]
			$poolId = $args[2]
			$nonAppPool = get-pool -ea silentlyContinue | select -first 1
			if(!$nonAppPool) {throw "there must be a non application pool existing"}
			$pool = [ADSI]("LDAP://localhost:389/cn=" + $args[2] + ",ou=applications,dc=vdi,dc=vmware,dc=int")
			# $fsp = [ADSI]("LDAP://localhost:389/cn=ForeignSecurityPrincipals,dc=vdi,dc=vmware,dc=int")
			$user = get-user -name $name -domain $domain | ?{$_.displayName -like "$domain*\$name"} 
			add-poolEntitlement -pool_id $nonAppPool.pool_id -sid $user.sid -ea silentlycontinue
			$dn = "cn=" + $user.sid + ",cn=ForeignSecurityPrincipals,dc=vdi,dc=vmware,dc=int"
			$pool.putex(3,"member",@($dn))
			$pool.setinfo()		
			remove-poolEntitlement -pool_id $nonAppPool.pool_id -sid $user.sid -forceremove:$true -ea silentlycontinue
		}
		$this.executePsRemote($cmd, $argList, $msg)
	} -Name entitleRdsAppPool
	
	$broker | Add-Member -MemberType ScriptMethod -Value { ##setPairingPassword
		Param($pairingPassword, $timeout)
		$msg = "set pairing password"
		$argList = @($pairingPassword, $timeout)
		$cmd = {
			$serverOu = [ADSI]"LDAP://localhost:389/ou=server,ou=properties,dc=vdi,dc=vmware,dc=int"
			$searcher = new-object System.DirectoryServices.DirectorySearcher($serverOu)
			$searcher.filter= ("(cn=" + $(hostname) + ")")
			$res = $searcher.findall()
			if ($res.count -ge 1) {
				$db = [ADSI] ($res[0].path)
				$db.put("pae-SecurityServerPairingPassword", $args[0])
				$db.put("pae-SecurityServerPairingPasswordTimeout", $args[1])
				$db.put("pae-SecurityServerPairingPasswordLastChangedTime", (get-date))
				$db.setinfo()
			} else {
				throw ("ERROR: Server " + $(hostname) + " not found")
			}
		}
		$this.executePsRemote($cmd, $argList, $msg)
	} -Name setPairingPassword
	
	$broker | Add-Member -MemberType ScriptMethod -Value { ##addTransferServer
		Param($vcAddress,$tsVmPath)
		$msg = "add transfer server"
		$vcId = $this.getVcId($vcAddress)
		$argList = @($vcId, $tsVmPath)
		$cmd = {
			Add-PSSnapin vm*
			Add-TransferServer -vc_id $args[0] -tsvm_path $args[1] -ea Stop
		}
		$this.executePsRemote($cmd, $argList, $msg)
	} -Name addTransferServer
	
	$broker | Add-Member -MemberType ScriptMethod -Value { ##removeTransferServer
		Param($tsVmName)
		$msg = "remove transfer server"
		$argList = @($tsVmName)
		$cmd = {
			Add-PSSnapin vm*
			if ($tsVmName -eq '*') { 
				get-TransferServer | remove-transferserver -ea Stop
			} else { 
				get-TransferServer -path "*$args[0]*" | remove-transferserver -ea Stop
			}
		}
		$this.executePsRemote($cmd, $argList, $msg)
	} -Name removeTransferServer
	
	$broker | Add-Member -MemberType ScriptMethod -Value { ##getVcId
		Param($vcAddress)
		$msg = "get VC ID"
		$argList = @($vcAddress)
		$cmd = {
			Add-PSSnapin vm*
			$vc = get-viewvc -name $args[0] -ea Stop
			if (!$vc){
				$vcName = [System.Net.Dns]::gethostentry($args[0]).hostname
				$vc = get-viewvc -name $vcName -ea SilentlyContinue
			}
			if (!$vc){
				throw 'Can not get VC ID'
			} else {
				return $vc.vc_id
			}
		}
		$cmdOutPut = $this.executePsRemote($cmd, $argList, $msg)
		return $cmdOutput
	} -Name getVcId
	
	$broker | Add-Member -MemberType ScriptMethod -Value { ##exportSettings
		Param($filePath)
		$msg = "export broker settings to $filePath"
		$folder = $filePath.replace($filePath.split('\')[-1],'')
		$cmd = "
			mkdir $folder -force
			& 'c:\program files\vmware\vmware view\server\tools\bin\vdmexport.exe' '-f' '$filePath' '-v' 2>`$null
			get-item $filePath
		"
		$this.executePsTxtRemote($cmd, $msg)
	} -Name exportSettings
	
	$broker | Add-Member -MemberType ScriptMethod -Value { ##importSettings
		Param($filePath)
		$msg = "import broker settings from $filePath"
		$cmd = "
			& 'c:\program files\vmware\vmware view\server\tools\bin\vdmimport.exe' '-f' '$filePath'
		"
		$this.executePsTxtRemote($cmd, $msg)
	} -Name importSettings
	
	return $broker	
}
	
function newRemoteWin {
	Param($ip, $admin, $passwd)	
	
	# for($i = 0; $i -lt 3; $i++){
		# if (test-wsman $ip) {break}
		# start-sleep 60
	# }
	#try {
		#Enable-WSManCredSSP -Role Client -DelegateComputer "*" -Force | out-null
	#} catch {
	#
	#}
	
	$cred = new-object -typeName System.management.automation.pscredential -argumentList $admin, (ConvertTo-SecureString $passwd -asPlainText -Force)

	try {
		$so = new-pssessionoption -operationtimeout 0
		$session = new-pssession -computername $ip -cred $cred -authentication CredSSP -sessionoption $so -EA SilentlyContinue
		if (!$session) {$session = new-pssession -computername $ip -cred $cred -sessionoption $so -EA Stop}
	} catch {
		writeCustomizedMsg "Fail - connect to remote Windows system"
		writeCustomizedMsg "debug - IP $ip"
		writeStderr
		[Environment]::exit("0")	
	}

	$remoteWin = New-Object PSObject -Property @{
		ip = $ip
		admin = $admin
		passwd = $passwd
		session = $session
		cred = $cred
	}
	
	writeCustomizedMsg "Success - connect to remote Windows machine $ip"
	
	$remoteWin | add-member -MemberType ScriptMethod -value { ##executePsRemote
		param ($script, $argumentList, $msg, $timeout = 3600)
		$job = invoke-command -asjob -scriptblock $script -session $this.session -argumentList $argumentList
		wait-job $job -timeout $timeout | out-null
		if ($job.state -eq "Running") {
			stop-job $job
			writeCustomizedMsg "Fail - execution timeout"
		# } elseif ($job.state -eq "Failed") {
			# try {
				# receive-job $job -ea Stop
			# } catch {
				# writeCustomizedMsg "Fail - $msg"
				# writeStderr
				# [Environment]::exit("0")
			# }
		} else {
			try {
				receive-job $job -keep -ea Stop | out-null
			} catch {
				writeCustomizedMsg "Fail - $msg"
				writeStderr
				[Environment]::exit("0")
			}
			writeCustomizedMsg "Success - $msg"	
		}
		$result = receive-job $job
		return $result
	} -name executePsRemote
	
	$remoteWin | add-member -MemberType ScriptMethod -value { ##executePsTxtRemote
		param ($script, $msg, $timeout = 3600)
		$script = [scriptblock]::Create($script)
		$argList = @()
		$result = $this.executePsRemote($script, $argList, $msg, $timeout)
		return $result
	} -name executePsTxtRemote
	
	$remoteWin | add-member -MemberType ScriptMethod -value { ##runInteractiveCmd
		param ($script, $timeout=120)
		$ip = $this.ip
		$guestUser = $this.admin
		$guestPassword = $this.passwd
		$script | set-content "..\www\upload\$ip.txt"
		$this.sendFile("..\www\upload\$ip.txt", "c:\temp\script.bat")
		$timeSuffix = get-date -format "-yyyy-MM-dd-hh-mm-ss"
		$cmd = "
			#schtasks /delete /f /tn runScript | out-null
			remove-item c:\temp\output*.txt -force -ea silentlycontinue
			`$date = get-date '12/31/2014'.replace('2014',(get-date).year+1) -format (Get-ItemProperty -path 'HKCU:\Control Panel\International').sshortdate
			schtasks /create /f /it /tn runScript /ru '$guestUser' /rp '$guestPassword' /rl HIGHEST /sc once /sd `$date /st 00:00:00 /tr 'c:\temp\script.bat > c:\temp\output$timeSuffix.txt' | out-null 
			schtasks /run /tn runScript | out-null
		"
		$this.executePsTxtRemote($cmd, "trigger interactive command in remote machine")
		$this.waitForTaskComplete("runScript", $timeout)
		$cmd = "
			get-content c:\temp\output$timeSuffix.txt
			schtasks /delete /f /tn runScript | out-null
		"
		$result = $this.executePsTxtRemote($cmd, "get script output")
		return $result
	} -name runInteractiveCmd
	
	$remoteWin | add-member -MemberType ScriptMethod -value { ##runInteractivePs1
		param ($script, $timeout=3600)
		$ip = $this.ip
		$guestUser = $this.admin
		$guestPassword = $this.passwd
		$script | set-content "..\www\upload\$ip.txt"
		$this.sendFile("..\www\upload\$ip.txt", "c:\temp\script.ps1")
		$timeSuffix = get-date -format "-yyyy-MM-dd-hh-mm-ss"
		$cmd = "
			'runscript task log' | out-file c:\temp\output$timeSuffix.txt
			`$date = get-date '12/31/2014'.replace('2014',(get-date).year+1) -format (Get-ItemProperty -path 'HKCU:\Control Panel\International').sshortdate
			schtasks /create /f /it /tn runScript /ru '$guestUser' /rp '$guestPassword' /rl HIGHEST /sc once /sd `$date ``
				/st 00:00:00 /tr 'powershell -windowstyle minimized -c ''powershell -c c:\temp\script.ps1 > ``
				c:\temp\output$timeSuffix.txt 2>&1''' | out-null
			schtasks /run /tn runScript | out-null
		"
		$this.executePsTxtRemote($cmd, "trigger interactive PS1 in remote machine")
		$this.waitForTaskComplete("runScript", $timeout)
		$cmd = "
			schtasks /delete /f /tn runScript | out-null
			get-content c:\temp\output$timeSuffix.txt
		"
		$result = $this.executePsTxtRemote($cmd, "get script output")
		return $result
	} -name runInteractivePs1
	
	$remoteWin | add-member -MemberType ScriptMethod -value { ##getHostname
		$hostname = $this.executePsRemote("hostname")
		return $hostname
	} -name getHostname
	
	$remoteWin | add-member -MemberType ScriptMethod -value { ##waitForSession
		param($delay=30, $timeout=600)
		$i = 0
		while (($this.session -eq $null) -and ($i * $delay -lt $timeout)) {
			$so = new-pssessionoption -operationtimeout 0
			$this.session = new-pssession -computername $this.ip -cred $this.cred -sessionoption $so -EA silentlyContinue
			if ($this.session -eq $null) {
				start-sleep $delay
			}
			$i++		
		} 
		if ($this.session -eq $null)
		{
			writeCustomizedMsg "Fail - setup remote Powershell session"
			[Environment]::exit("0")
		} 
	} -name waitForSession
	
	$remoteWin | add-member -MemberType ScriptMethod -value { ##waitForProcessExit
		Param($procName, $timeout=300)
		$i = 0
		do {
			$proc = invoke-command {get-process $args[0]} -session $this.session -argumentlist $procName
			start-sleep 10
			$i++
		} while (($proc -ne $null) -and ($i * 10 -lt $timeout))
		if ($proc -ne $null)
		{
			writeCustomizedMsg "Fail - wait process $procName to exit"
			[Environment]::exit("0")
		}
	} -name waitForProcessExit
	
	$remoteWin | add-member -MemberType ScriptMethod -value { ##waitForTaskComplete1
		Param($taskName, $timeout=600)
		$i = 0
		$schedule = new-object -com "Schedule.Service"
		try {
			$schedule.connect($this.ip, "", $this.admin, $this.passwd)
		} catch {
			writeCustomizedMsg "Fail - connect to task scheduler on remote machine"
			writeStderr
			[Environment]::exit("0")	
		}
		do {
			$task = $schedule.getfolder("\").gettasks(0) | ?{$_.NAME -eq $taskName} | SELECT state,lasttaskresult
			start-sleep 10
			$i++
		} while (($task.state -eq 4) -and ($i * 10 -lt $timeout))
		writeCustomizedMsg "Info - task state $($task.state) task result $($task.lastTaskResult)"
		if ($task.state -ne 3) {
			writeCustomizedMsg "Fail - wait task $taskName to complete"
			[Environment]::exit("0")
		} else {
			writeCustomizedMsg "Success - wait task $taskName to complete"
		}
	} -name waitForTaskComplete1
	
	$remoteWin | add-member -MemberType ScriptMethod -value { ##waitForTaskComplete
		Param($taskName, $timeout=600)
		$cmd = {
			param($taskName, $timeout)
			$i = 0
			$schedule = new-object -com "Schedule.Service"
			$schedule.connect("127.0.0.1")
			do {
				$task = $schedule.getfolder("\").gettasks(0) | ?{$_.NAME -eq $taskName} | SELECT state,lasttaskresult
				start-sleep 10
				$i++
			} while (($task.state -eq 4) -and ($i * 10 -lt $timeout))
			if ($task.state -ne 3) {
				return "Fail - wait task $taskName to complete"
			} else {
				return "Success - wait task $taskName to complete"
			}
		}
		$result = invoke-command -scriptblock $cmd -session $this.session -argumentList $taskName,$timeout
		writeCustomizedMsg $result
		if($result -match "Fail -"){[Environment]::exit("0")}
	} -name waitForTaskComplete
	
	$remoteWin | Add-Member -MemberType ScriptMethod -Value { ##restart
		$cmd = {
			restart-computer -force -confirm:$false
		}
		invoke-command -scriptblock $cmd -session $this.session	
		remove-pssession $this.session
		$this.session = $null
		# try {
			# restart-computer -computerName $this.ip -credential $this.cred -force -wait -timeout 300 -ea stop
		# } catch {
			# writeCustomizedMsg "Fail - restart remote Windows machine"
			# writeStderr
			# [Environment]::exit("0")	
		# }
		writeCustomizedMsg "Success - restart remote Windows machine"
	} -Name restart
	
	$remoteWin | Add-Member -MemberType ScriptMethod -Value { ##sendFile
		param($source,$destination)

		Set-StrictMode -Version Latest

		$sourcePath = (Resolve-Path $source).Path
		$sourceBytes = [IO.File]::ReadAllBytes($sourcePath)
		$streamChunks = @()

		$streamSize = 1MB
		for($position = 0; $position -lt $sourceBytes.Length;
			$position += $streamSize)
		{
			$remaining = $sourceBytes.Length - $position
			$remaining = [Math]::Min($remaining, $streamSize)

			$nextChunk = New-Object byte[] $remaining
			[Array]::Copy($sourcebytes, $position, $nextChunk, 0, $remaining)
			$streamChunks += ,$nextChunk
		}
		
		if ($destination.endswith("\")) {
			$destination = $destination + (get-childitem $source).Name
		}

		$remoteScript = {
			param($destination, $length)

			$folder = $destination.replace($destination.split("\")[-1],"")
			mkdir $folder -force

			$Destination = $executionContext.SessionState.`
				Path.GetUnresolvedProviderPathFromPSPath($Destination)
				
			Remove-Item $destination -confirm:$false -EA SilentlyContinue

			$destBytes = New-Object byte[] $length
			$position = 0

			foreach($chunk in $input)
			{
				# [GC]::Collect()
				[Array]::Copy($chunk, 0, $destBytes, $position, $chunk.Length)
				$position += $chunk.Length
			}

			[IO.File]::WriteAllBytes($destination, $destBytes)

			try {
				Get-Item $destination -EA stop | out-null
			} catch {
				return $false
			}
			# [GC]::Collect()
			return $true
		}

		$result = $streamChunks | Invoke-Command -Session $this.session $remoteScript `
			-ArgumentList $destination,$sourceBytes.Length
		if ($result) {
			writeCustomizedMsg "Success - send file to remote machine"
		} else {
			writeCustomizedMsg "Fail - send file to remote machine"
			[Environment]::exit("0")
		}
	
	} -Name sendFile
	
	$remoteWin | add-member -MemberType ScriptMethod -Value { ##autoAdminLogon
		Param ($type="local")
		$cmd = {
			param($userName,$password)
			$regPath = "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
			reg copy "$regPath" "$regPath-bak" /f
			$regPath = $regPath.replace("HKLM\","HKLM:\")
			set-itemproperty -path $regPath -name AutoAdminLogon -value 1 -force
			set-itemproperty -path $regPath -name AutoLogonCount -value 999 -force
			set-itemproperty -path $regPath -name DefaultUserName -value $userName -force
			set-itemproperty -path $regPath -name DefaultPassword -value $password -force
			set-itemproperty -path $regPath -name DefaultDomainName -value '' -force
		}
		invoke-command -scriptblock $cmd -session $this.session -argumentList $this.admin,$this.passwd
		if ($type -eq "domain") {
			$cmd = {				
				$domain = get-itemproperty -path 'HKLM:\system\currentcontrolset\services\tcpip\parameters' -name 'nv domain' -ea SilentlyContinue
				if ($domain -eq $null) {
					$domain = ''
				} else {
					$domain = $domain.'nv domain'
				}
				set-itemproperty -path $regPath -name DefaultDomainName -value $domain -force
				set-itemproperty -path $regPath -name AltDefaultDomainName -value $domain -force
			}
			invoke-command -scriptblock $cmd -session $this.session
		}
		$this.restart()
	} -name autoAdminLogon
	
	$remoteWin | add-member -MemberType ScriptMethod -Value { ##noAutoLogon
    	$cmd = {
			$regPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
			set-itemproperty -path $regPath -name AutoAdminLogon -value 0 -force
		}
		invoke-command -scriptblock $cmd -session $this.session
		$this.restart()
	} -name noAutoAdminLogon
	
	$remoteWin | add-member -MemberType ScriptMethod -Value { ##getInstalledApp
		$cmd = {
			$current = $host.ui.rawui.buffersize
			$current.width = 128
			$host.ui.rawui.buffersize = $current
			$current = $host.ui.rawui.windowsize
			$current.width = 128
			$host.ui.rawui.windowsize = $current
			$app = get-wmiobject -class win32_product | select name, vendor, version
			$appXml = convertTo-xml -inputObject $app -as string -notypeinformation
			$appXml.trimstart('<?xml version="1.0"?>')
		}
		$output = invoke-command -scriptblock $cmd -session $this.session
		return $output
	} -name getInstalledApp
	
	$remoteWin | add-member -MemberType ScriptMethod -Value { ##setWinUpdate
		param($switch)
		if ($switch -eq "on") {
			$cmd = {
				set-service wuauserv -startuptype automatic
				start-service wuauserv
			}
		} else {
			$cmd = {
				set-service wuauserv -startuptype disabled
				stop-service wuauserv
			}
		}
		invoke-command -scriptblock $cmd -session $this.session
	} -name setWinUpdate
	
	$remoteWin | add-member -MemberType ScriptMethod -Value { ##trustVMwareSignature
		param() 
		if (invoke-command {(get-wmiobject -class win32_operatingsystem).version -gt 6.0} -session $this.session) {
			$this.sendFile("..\postinstall\vmware_2013.cer","c:\temp\")
			$this.sendFile("..\postinstall\vmware_2016.cer","c:\temp\")
			$this.sendFile("..\postinstall\fabula_2015.cer","c:\temp\")
		} else {
			# $this.sendFile("..\postinstall\certutil.exe","c:\windows\system32\")
			# $this.sendFile("..\postinstall\certadm.dll","c:\windows\system32\")
			$this.sendFile("..\postinstall\DriverSignPolicy.exe","c:\temp\")
		}
		$msg = "trust VMware signature"
		$argList = @()
		$cmd = {
			if (test-path c:\Windows\system32\CertUtil.exe) {
				c:\Windows\System32\CertUtil.exe -Enterprise -addstore 'TrustedPublisher' c:\temp\vmware_2013.cer | out-null
				c:\Windows\System32\CertUtil.exe -Enterprise -addstore 'TrustedPublisher' c:\temp\vmware_2016.cer | out-null
				c:\Windows\System32\CertUtil.exe -Enterprise -addstore 'TrustedPublisher' c:\temp\fabula_2015.cer | out-null
				remove-item c:\temp\*.cer -force
			} else {
				# $regPath = 'HKLM:\SOFTWARE\Microsoft\Driver Signing'
				# set-itemproperty -force -path $regPath -name Policy -value 0
				c:\temp\DriverSignPolicy.exe 0
				remove-item c:\temp\DriverSignPolicy.exe -force
			}
		}
		$this.executePsRemote($cmd, $argList, $msg)
	} -name trustVMwareSignature
	
	$remoteWin | add-member -MemberType ScriptMethod -Value {
		$msg = "enable RDP on " + $this.ip
		$argList = @()
		$cmd = {
			$regPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server'
			set-itemproperty -force -path $regPath -name fDenyTSConnections -value 0
			netsh firewall set service remoteadmin enable
			netsh firewall set service remotedesktop enable
		}
		$this.executePsRemote($cmd, $argList, $msg)
	} -name enableRdp
	
	$remoteWin | add-member -MemberType ScriptMethod -Value {
		$ver = invoke-command {(get-wmiobject -class win32_operatingsystem).version} -session $this.session
		return $ver
	} -name getOsVersion
	
	$remoteWin | add-member -MemberType ScriptMethod -Value {
		$isX64 = invoke-command {Test-Path c:\Windows\syswow64} -session $this.session
		if($isX64) {
			return "x64"
		} else {
			return "x86"
		}
	} -name getOsType
	
	$remoteWin | add-member -MemberType ScriptMethod -Value { ##readFile
		param($filePath,$numberOfLine)
		$argList = @($filePath,$numberOfLine)
		$cmd = {
			$number = [int]$args[1]
			if (!$number) {
				get-content $args[0]
			} elseif ($number -gt 0) {
				get-content $args[0] | select -first $number
			} elseif ($number -lt 0) {
				get-content $args[0] | select -last (-$number)
			} else {
				throw "invalid number of line"
			}
		}
		$fileContent = $this.executePsRemote($cmd, $argList, "read file in remote machine")
		return $fileContent
	} -name readFile
	
	return $remoteWin
}

function writeStdout {
	Param($output)
	if($runFromWeb) {
		Write-Output "<stdOutput><![CDATA[$output]]></stdOutput>"
	} else {
		Write-Output $output
	}
}

function writeStderr {
	if($runFromWeb) {
		$errMessage = @"
<exceptionType>$($_.Exception.GetType())</exceptionType>
<fullyQualifiedErrorId>$($_.FullyQualifiedErrorId)</fullyQualifiedErrorId>
<errMessage><![CDATA[$($_.Exception.Message)]]></errMessage>
<scriptName>$($_.InvocationInfo.ScriptName)</scriptName>
<scriptLineNumber>$($_.InvocationInfo.ScriptLineNumber)</scriptLineNumber>
<offsetInLine>$($_.InvocationInfo.OffsetInLine)</offsetInLine>
"@
		Write-Host "<stderr>$errMessage</stderr>"
	} else {
		Write-Error $_.exception 
	}
}

function writeCustomizedMsg {
	Param($message)
	if($runFromWeb) {
		$message = [System.Net.WebUtility]::HtmlEncode($message)
		$logtime = get-date -format "[yyyy-MM-dd HH:mm:ss] "
		Write-Host "<customizedOutput>$logtime$message</customizedOutput>"
	} else {
		if ($message -match "^Success") {
			Write-Host -ForegroundColor Green $message
		} elseif ($message -match "^Fail") {
			Write-Host -ForegroundColor Red $message
		} elseif ($message -match "^Warn") {
			Write-Host -ForegroundColor Yellow $message
		} else {
			Write-Host $message
		}
	}
}

function writeSeparator {
	if($runFromWeb) {
		"<separator/>"
	} else {
		"`n------------------------------------------------------------`n"
	}
}

function outputObj {
	param($obj, $name)
	if($runFromWeb) {
		$xml = $obj | convertTo-xml -as string -notypeinformation
		$xml = $xml.trimstart('<?xml version="1.0"?>')
		$xml = $xml.replace('<Objects>','').replace('</Objects>','')
		$xml = $xml.replace('Object',$name).trim()
		$xml
	} else {
		"$name`:"
		$obj | ft
	}
}

function writeXml {
	param($xml)
	if($runFromWeb) {
		$xml
	}
}

function writeLink {
	param($title, $url)
	if($runFromWeb) {
		write-host "<link><title>$title</title><url><![CDATA[$url]]></url></link>"
	} else {
		write-host "$title - $url"
	}
}

function getWebCommanderJobResult {
	get-job | wait-job | out-null
	foreach($job in get-job) {
		$result = [XML](receive-job $job).content
		if ($result.webcommander.returnCode -eq '4488') {
			writeCustomizedMsg "Success - run job $($job.name)"
		} else {
			writeCustomizedMsg "Fail - run job $($job.name)"
			$result.webcommander.returnCode
			#$result.save([console]::out)
		}
		$result.webcommander.result.outerxml
	}
	get-job | remove-job
}

function getVivmList {
	param($vmName, $serverAddress, $serverUser, $serverPassword)
	$vmNameList = parseInput $vmName
	$server = newServer $serverAddress $serverUser $serverPassword
	$vivmList = get-vm -name $vmNameList -server $server.viserver -EA SilentlyContinue
	if (!$vivmList) {
		writeCustomizedMsg "Fail - get VM $vmName"
		[Environment]::exit("0")
	}
	$vivmList = $vivmList | select -uniq
	return $vivmList
}

function getVmIpList {
	param($vmName, $serverAddress, $serverUser, $serverPassword)
	$ipList = @()
	$vmNameList = parseInput $vmName	
	foreach ($vmName in $vmNameList) {
		$ip = verifyIp($vmName)
		if ($ip) {
			$ipList += $ip
		} else {
			if (!$server) {
				$server = newServer $serverAddress $serverUser $serverPassword
			}
			$vivmList = get-vm -name "$vmName" -server $server.viserver -EA SilentlyContinue
			if (!$vivmList) {
				writeCustomizedMsg "Fail - get VM $vmName"
				#[Environment]::exit("0")
			} else {
				$vivmList | % { 
					$vm = newVmWin $server $_.name $guestUser $guestPassword
					$vm.waitfortools()
					$ip = $vm.getIPv4()
					$vm.enablePsRemote()
					$ipList += $ip
				}
			}
		}	
	}
	$ipList = $ipList | select -uniq
	return $ipList
}

function getFileList {
	param($fileUrl)
	$files = @()
	$fileList = @($fileUrl.split("`n") | %{$_.trim()})
	$wc = new-object system.net.webclient;	
	$fileList | % {
		if (test-path $_) {
			$files += $_
		} elseif (invoke-webrequest $_) {
			$fileName = ($_.split("/"))[-1]
			$path = resolve-path "..\www\upload"
			$wc.downloadfile($_, "$path\$fileName")
			$files += "$path\$fileName"
		}
	}
	return $files
}

function restoreSnapshot {
	param($ssName, $vmName, $serverAddress, $serverUser, $serverPassword)
	$server = newServer $serverAddress $serverUser $serverPassword
	$vmNameList = parseInput $vmName
	$vivmList = get-vm -name $vmNameList -server $server.viserver -EA SilentlyContinue
	if (!$vivmList) {
		writeCustomizedMsg "Fail - get VM $vmName"
		[Environment]::exit("0")
	}
	$vmList | % { 
		$vm = newVmWin $server $_.name $guestUser $guestPassword
		$vm.restoreSnapshot($ssName)
		$vm.start()
		$vm.waitfortools()
	}	
}

function parseInput {
	param($content)
	try {
		$c = @(invoke-expression $content)
		$c[0].tostring()
	} catch {
		$c = @($content.split(",") | %{$_.trim()})
	}
	return $c
}