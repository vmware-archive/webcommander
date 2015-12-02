function getWinList {
	param($winAddress, $winUser, $winPassword)
	$addressList = @($winAddress.split(",") | %{$_.trim()})
	$winList = @()
  foreach ($addr in $addressList) {
    $win = newRemoteWin $addr $winUser $winPassword
    $winList += $win 
  }
	if (!$winList) {
		addToResult "Fail - get Windows machine"
		endExec
	}
	$winList = $winList | select -uniq
	return $winList
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
		addToResult "Fail - connect to remote Windows system"
		endError
	}

	$remoteWin = New-Object PSObject -Property @{
		ip = $ip
		admin = $admin
		passwd = $passwd
		session = $session
		cred = $cred
	}
	
	addToResult "Success - connect to remote Windows machine $ip"
	
	$remoteWin | add-member -MemberType ScriptMethod -value { ##executePsRemote
		param ($script, $argumentList, $msg, $timeout = 3600)
		$job = invoke-command -asjob -scriptblock $script -session $this.session -argumentList $argumentList
		wait-job $job -timeout $timeout | out-null
		if ($job.state -eq "Running") {
			stop-job $job
			addToResult "Fail - execution timeout"
		} else {
			try {
				receive-job $job -keep -ea Stop | out-null
			} catch {
				addToResult "Fail - $msg"
				endError
			}
			addToResult "Success - $msg"	
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
		$script | set-content "..\www\upload\$ip.txt"
		$this.sendFile("..\www\upload\$ip.txt", "c:\temp\script.bat")
		$timeSuffix = get-date -format "-yyyy-MM-dd-hh-mm-ss"
		$cmd = "
			#schtasks /delete /f /tn runScript | out-null
			remove-item c:\temp\output*.txt -force -ea silentlycontinue
			`$date = get-date '12/31/2014'.replace('2014',(get-date).year+1) -format (Get-ItemProperty -path 'HKCU:\Control Panel\International').sshortdate
			schtasks /create /f /it /tn runScript /ru '$($this.admin)' /rp '$($this.passwd)' /rl HIGHEST /sc once /sd `$date /st 00:00:00 /tr 'c:\temp\script.bat > c:\temp\output$timeSuffix.txt' | out-null 
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
		$script | set-content "..\www\upload\$ip.txt"
		$this.sendFile("..\www\upload\$ip.txt", "c:\temp\script.ps1")
		$timeSuffix = get-date -format "-yyyy-MM-dd-hh-mm-ss"
		$cmd = "
			'runscript task log' | out-file c:\temp\output$timeSuffix.txt
			`$date = get-date '12/31/2014'.replace('2014',(get-date).year+1) -format (Get-ItemProperty -path 'HKCU:\Control Panel\International').sshortdate
			schtasks /create /f /it /tn runScript /ru '$($this.admin)' /rp '$($this.passwd)' /rl HIGHEST /sc once /sd `$date ``
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
			addToResult "Fail - setup remote Powershell session"
			endExec
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
			addToResult "Fail - wait process $procName to exit"
			endExec
		}
	} -name waitForProcessExit
	
	$remoteWin | add-member -MemberType ScriptMethod -value { ##waitForTaskComplete1
		Param($taskName, $timeout=600)
		$i = 0
		$schedule = new-object -com "Schedule.Service"
		try {
			$schedule.connect($this.ip, "", $this.admin, $this.passwd)
		} catch {
			addToResult "Fail - connect to task scheduler on remote machine"
			endError	
		}
		do {
			$task = $schedule.getfolder("\").gettasks(0) | ?{$_.NAME -eq $taskName} | SELECT state,lasttaskresult
			start-sleep 10
			$i++
		} while (($task.state -eq 4) -and ($i * 10 -lt $timeout))
		addToResult "Info - task state $($task.state) task result $($task.lastTaskResult)"
		if ($task.state -ne 3) {
			addToResult "Fail - wait task $taskName to complete"
			endExec
		} else {
			addToResult "Success - wait task $taskName to complete"
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
		addToResult $result
		if($result -match "Fail -"){endExec}
	} -name waitForTaskComplete
	
	$remoteWin | Add-Member -MemberType ScriptMethod -Value { ##restart
		$cmd = {
			restart-computer -force -confirm:$false
		}
		invoke-command -scriptblock $cmd -session $this.session	
		remove-pssession $this.session
		$this.session = $null
		addToResult "Success - restart remote Windows machine"
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
			addToResult "Success - send file to remote machine"
		} else {
			addToResult "Fail - send file to remote machine"
			endExec
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
		invoke-command -scriptblock $cmd -session $this.session -argumentList $this.admin,$this.passwd | out-null
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
			invoke-command -scriptblock $cmd -session $this.session | out-null
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
			get-wmiobject -class win32_product
		}
		$app = invoke-command -scriptblock $cmd -session $this.session | select name, vendor, version
		addToResult $app "dataset"
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
			set-itemproperty -force -path $regPath -name fDenyTSConnections -value 0 | out-null
			netsh firewall set service remoteadmin enable | out-null
			netsh firewall set service remotedesktop enable | out-null
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
  
  $remoteWin | add-member -MemberType ScriptMethod -Value { ##changeHostName
		param($newHostName)
		$cmd = {
      param($newName, $password, $userName)
      (Get-WmiObject -class win32_computersystem).Rename($newName, $password, $userName)
    }
    $result = invoke-command -scriptblock $cmd -session $this.session -argumentlist $newHostName, $this.admin, $this.passwd
    if ($result.returnValue -eq 0) {
      addToResult "Success - rename hostname to $newGuestName"
      $this.restart()
    } else {
      addToResult "Fail - rename hostname to $newGuestName"
      addToResult ("Info - return value is " + $result.returnvalue)
    }	
	} -name changeHostName
  
  $remoteWin | add-member -MemberType ScriptMethod -Value { ##windowsUpdate
		param($updateServer, $severity)
    $autoLogonScript = "powershell set-executionpolicy unrestricted; powershell c:\temp\updateWindows2.ps1 -updateServer $updateServer -severity $severity"
    $tempFileName = "$winAddress.bat"
    $autoLogonScript | Set-Content .\$tempFileName

    $cmd = {
      $regPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
      new-itemproperty -path $regPath -name WinUpdate -value 'C:\temp\updateWindows.bat' -Confirm:$false -force
    }
    invoke-command -scriptblock $cmd -session $this.session | out-null

    $update_script = ".\windows\updateWindows2.ps1"
    $this.sendFile($update_script,"c:\temp\")
    $this.sendFile(".\$tempFileName","c:\temp\updateWindows.bat")
    remove-item ".\$tempFileName"
    $this.autoAdminLogon("local")
    addToResult "Success - trigger Windows update task"
	} -name windowsUpdate
  
  $remoteWin | add-member -MemberType ScriptMethod -Value { ##windowsUpdateSync
    param ($updateServer, $severity)
    $this.sendFile(".\windows\updateWindowsSync2.ps1", "c:\temp\wu.ps1")
    $timeSuffix = get-date -format "-yyyy-MM-dd-hh-mm-ss"
    $cmd = "
      set-executionpolicy unrestricted -force
      `$date = get-date '12/31/2014'.replace('2014',(get-date).year+1) -format (Get-ItemProperty -path 'HKCU:\Control Panel\International').sshortdate
      schtasks /create /f /tn windowsupdate /ru '$($this.admin)' /rp '$($this.passwd)' /rl HIGHEST /sc once /sd `$date /st 00:00:00 /tr 'powershell c:\temp\wu.ps1 $updateserver $severity >>c:\temp\wu$timeSuffix.log' | out-null
    "
    $this.executePsTxtRemote($cmd, "create Windows update task in VM")
    do {
      $cmd = "schtasks /run /tn windowsupdate | out-null"
      $this.executePsTxtRemote($cmd, "trigger Windows update task in VM")
      $cmd = "
        start-sleep 10
        `$s = new-object -com 'Schedule.Service'
        `$s.connect()
        do {
          `$task = `$s.getfolder('\').gettasks(0) | where {`$_.NAME -eq 'windowsupdate'} | SELECT state,lasttaskresult
          if (`$task.state -eq 3){break}
          start-sleep 30
        } while ((`$task.state -eq 4) -or (`$task.state -eq 2) -or !(test-path c:\temp\wu$timeSuffix.log))
        start-sleep 10
        get-content c:\temp\wu$timeSuffix.log -ea SilentlyContinue | select -last 1
      "
      $result = $this.executePsTxtRemote($cmd, "get update progress", 86400)
      if ($result -match "need to reboot") {
        $this.restart()
        start-sleep 100
        $this.waitforsession(30, 600)
      }
    } while ($result -notmatch "no more update")
    addToResult "Success - install Windows update"
    $cmd = "
      schtasks /delete /f /tn windowsupdate | out-null
      get-content c:\temp\wu$timeSuffix.log
    "
    $result = $this.executePsTxtRemote($cmd, "get update log")
    addToResult $result "raw"
  } -name windowsUpdateSync
  
  $remoteWin | add-member -MemberType ScriptMethod -Value { ##checkWindowsUpdate
		param($updateServer="External", $severity="Low")
		$cmd = {
      $objServiceManager = New-Object -ComObject "Microsoft.Update.ServiceManager"
      $objSession = New-Object -ComObject "Microsoft.Update.Session"
      $objSearcher = $objSession.CreateUpdateSearcher()

      If ($args[0] -eq "External"){
        $objSearcher.ServerSelection = 2
      } else {
        $objSearcher.ServerSelection = 1
      }

      $objCollection = New-Object -ComObject "Microsoft.Update.UpdateColl"
      $objResults = $objSearcher.Search("IsInstalled=0")

      switch ($args[1]){
        "Critical" {$updates = $objResults.Updates | where {$_.MsrcSeverity -eq "Critical"}}
        "Important" {$updates = $objResults.Updates | where {("Important", "Critical") -contains $_.MsrcSeverity}}
        "Moderate" {$updates = $objResults.Updates | where {("Moderate", "Important", "Critical") -contains $_.MsrcSeverity}}
        "Low" {$updates = $objResults.Updates | where {("Low", "Moderate", "Important", "Critical") -contains $_.MsrcSeverity}}
        default {$updates = $objResults.Updates}
      }
      
      $toInstall = @()

      foreach($Update in $updates){     
        if (($Update.title -notmatch "Language") `
          -and ($Update.title -notlike "Windows Internet Explorer * for Windows *") `
          -and ($Update.title -notlike "Internet Explorer * for Windows *") `
          -and ($Update.title -notlike "Service Pack * for Windows *") `
          -and ($Update.title -notmatch "Genuine"))
        {
          $toInstall += $update
        }
      }
      return $toInstall
    }
    $result = invoke-command -scriptblock $cmd -session $this.session -argumentlist `
      $updateServer, $severity | select title, MsrcSeverity

    if ($result -eq "") {
      addToResult "Info - Windows is up-to-date"
    } else {
      addToResult "Info - the following updates are available"
      addToResult $result "dataset"
    }
	} -name checkWindowsUpdate
	
	return $remoteWin
}