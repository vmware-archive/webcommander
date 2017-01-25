$get_DesktopState = {
  Param ($poolId)
  Add-PSSnapin -Name vmware* -ea SilentlyContinue | out-null
  function GetDesktopVMState { 
    param ($Desktop,$pool,$sessions)
    if($Desktop.GetType().Name -eq "DesktopVM"){
      if($Desktop.isInPool -eq "false"){
        return "notManagedByView"
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
      if (($vmState -eq "CLONING") -or ($vmState -eq "UNDEFINED") -or 
        ($vmState -eq "PRE_PROVISIONED")) {
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
        if (($pool.persistence -eq "Persistent") -and ($Desktop.user_sid.Length -le 0) -or 
          ($Desktop.user_displayname -ne $desktop_sessions[0].Username)) {
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
        addError "Failed to determine state for VM: $($Desktop.Name)"
        break
      }
      return $stateString;      
    } else {
      throw "Object is not a DesktopVM"
    }
  }
  function addState{
    param($pool)
    $desktops = Get-DesktopVM -IsInPool $true -pool_id $pool.pool_id -ea SilentlyContinue
    $sessions = (Get-RemoteSession -pool_id $pool.pool_id -ea SilentlyContinue)
    $dt = @()
    if ($desktops) {
      foreach ($desktop in $desktops){
        $state = GetDesktopVMState $desktop $pool $sessions
        $dt += $desktop | add-member -name state -value $state -memberType noteproperty -passthru
      }
      return $dt
    }
  }  
  $poolIdList = $poolId.split(",") | %{$_.trim()}
  $pools = get-pool -pool_id $poolIdList -ea SilentlyContinue
  $ds = @()
  foreach ($p in $pools) {
    $ds += addState($p)
  }
  return $ds
}

$set_EventDb = {
  Param (
    $dbAddress, 
    $dbType,
    $dbPort,
    $dbName,
    $dbUser,
    $dbPassword,
    $tablePrefix
  )
  function Invoke-ModifyEventDatabase() {
    param( [ADSI] $db = $(throw "Event database entry required"),
      [String] $hostname = $(Read-Host -prompt "Hostname"),
      [String] $port = $(Read-Host -prompt "Port"),
      [String] $dbname = $(Read-Host -prompt "DB Name"),
      [String] $user = $(Read-Host -prompt "User"),
      [String] $password = $(Read-Host -prompt "Password"),
      [String] $tableprefix = "manualeventdb",
      [String] $servertype = "SQLSERVER")
    $db.put("description", "Manually modified entry at " + (get-date))
    $db.put("pae-databasepassword", $password)
    $db.put("pae-DatabasePortNumber", $port)
    $db.put("pae-DatabaseServerType", $servertype)
    $db.put("pae-DatabaseUsername", $user)
    $db.put("pae-DatabaseName", $dbname)
    $db.put("pae-DatabaseTablePrefix", $tableprefix)
    $db.put("pae-DatabaseHostName", $hostname)
    $db.setinfo()
    return $db
  }
  function Get-EventDatabase() {
    $dbou = [ADSI]"LDAP://localhost:389/OU=Database,OU=Properties,DC=vdi,DC=vmware,DC=int"
    $searcher = new-object System.DirectoryServices.DirectorySearcher($dbou)
    $searcher.filter="(objectclass=pae-EventDatabase)"
    $res = $searcher.findall()
    if ($res.count -eq 1) {
      return [ADSI] ($res[0].path)
    } else {
      return $null
    }
  }
  function New-EventDatabase() {
    param( [String] $hostname = $(Read-Host -prompt "Hostname"),
      [String] $port = $(Read-Host -prompt "Port"),
      [String] $dbname = $(Read-Host -prompt "DB Name"),
      [String] $user = $(Read-Host -prompt "User"),
      [String] $password = $(Read-Host -prompt "Password"),
      [String] $tableprefix = "manualeventdb",
      [String] $servertype = "SQLSERVER")

    $db = (Get-EventDatabase)
    if ($db -ne $null) {
    throw "The event database already exists"
    }
    $dbou = [ADSI]"LDAP://localhost:389/OU=Database,OU=Properties,DC=vdi,DC=vmware,DC=int"
    $guid = [GUID]::NewGuid()
    $db = $dbou.Create("pae-EventDatabase", "cn=" + $guid)
    Invoke-ModifyEventDatabase $db $hostname $port $dbname $user $password $tableprefix $servertype
  }
  function Set-EventDatabase() {
    param( [String] $hostname = $(Read-Host -prompt "Hostname"),
      [String] $port = $(Read-Host -prompt "Port"),
      [String] $dbname = $(Read-Host -prompt "DB Name"),
      [String] $user = $(Read-Host -prompt "User"),
      [String] $password = $(Read-Host -prompt "Password"),
      [String] $tableprefix = "manualeventdb",
      [String] $servertype = "SQLSERVER")

    $db = (Get-EventDatabase)
    if ($db -eq $null) {
      throw "The event database entry does not already exist"
    }
    Invoke-ModifyEventDatabase $db $hostname $port $dbname $user $password $tableprefix $servertype
  }
  $db = (Get-EventDatabase)
  if ($db -eq $null) {
    New-EventDatabase $dbAddress $dbPort $dbName $dbUser $dbPassword $tablePrefix $dbType
  } else {
    Invoke-ModifyEventDatabase $db $dbAddress $dbPort $dbName $dbUser $dbPassword $tablePrefix $dbType
  }
}

function newBroker {
  Param($ip,$admin,$password)

  $broker = newRemoteWin $ip $admin $password

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
      if ($args[1]) {
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
    Param($poolId,$enable)
    $msg = "set pool auto-recovery $action"
    $argList = @($poolId,$enable)
    $cmd = {
      $pool = [ADSI]("LDAP://localhost:389/cn=" + $args[0] + ",ou=Server Groups,dc=vdi,dc=vmware,dc=int")
      if ($args[1]) {
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