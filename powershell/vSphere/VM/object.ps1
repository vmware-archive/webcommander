function getVivmList {
  param($vmName, $server)
  $vmNameList = @($vmName.split(",") | %{$_.trim()})
  $vivmList = get-vm -name $vmNameList -server $server.viserver -EA SilentlyContinue
  if (!$vivmList) {
    addToResult "Fail - get VM $vmName"
    endExec
  }
  $vivmList = $vivmList | select -uniq
  return $vivmList
}

function newVm {
  Param($server,$name,$user,$password)

  try {
    $vivm = get-vm -Name $name -Server $server.viserver -wa 0 -EA stop
  } catch {
    addToResult "Fail - get VM $name"
    endError
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
        addToResult "Success - start VM $($this.name)"
      } else {
        addToResult "Fail - start VM $($this.name)"
        endExec
      }
    } else {
      addToResult "Info - VM $($this.name) is already powered on"
    }
    $this.waitForTools()
  } -name start
  
  $vm | Add-Member -MemberType ScriptMethod -Value { ##stop
    $i = 0
    do {
      $this.vivm = get-vm $this.name -server $this.server.viserver
      if ($this.vivm.powerstate -eq "PoweredOff"){
        addToResult "Info - VM $($this.name) is powered off"
        return
      } else {
        Shutdown-VMGuest -vm $this.vivm -server $this.server.viserver -confirm:$false | out-null
        start-sleep 30
        $i++
      }      
    } while ($i -lt 10)
    $null = stop-vm -vm $this.vivm -confirm:$false
    addToResult "Warning - VM $($this.name) is killed forcely"
  } -Name stop
  
  $vm | Add-Member -MemberType ScriptMethod -Value { ##suspend
    $this.vivm = get-vm $this.name -server $this.server.viserver
    try {
      $null = Suspend-VM -vm $this.vivm -confirm:$false -EA stop
    } catch {
      addToResult "Fail - suspend VM $($this.name)"
      endError
    }
    addToResult "Sucess - suspend VM $($this.name)"
  } -Name suspend
  
  $vm | Add-Member -MemberType ScriptMethod -Value { ##restart
    $this.waitForTools()
    $this.vivm = get-vm $this.name -server $this.server.viserver
    try {
      $null = Restart-VMGuest -vm $this.vivm -confirm:$false -EA stop
    } catch {
      addToResult "Fail - restart VM $($this.name)"
      endError
    }
    addToResult "Success - restart VM $($this.name)"
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
    if ($status -ne "guestToolsRunning")
    {
      addToResult "Fail - VMware Tools is not running in the VM"
      endExec
    }
  } -name waitForTools
  
  $vm | add-member -MemberType ScriptMethod -Value { ##runScript
    Param($script, $type, $runAsync=$false)
    $this.waitForTools()
    $params = @{
      scriptText = $script;
      scriptType = $type;
      vm = $this.vivm;
      guestUser = $this.user;
      guestPassword = $this.password;
      confirm = $false;
      server = $this.server.viserver;
      hostUser = $this.server.admin;
      hostPassword = $this.server.passwd
    }
    if ($runAsync) {$params.RunAsync = $true}
    else {$params.ToolsWaitSecs = 60}
    try {
      $output = Invoke-VMScript @params
    } catch {
      addToResult "Fail - run VM script $script"
      endError
    }  
    return $output.scriptoutput
  } -name runScript
  
  $vm | add-member -MemberType ScriptMethod -Value { ##copyFileToVm
    Param($file,$dst)
    $file = resolve-path $file
    if ($dst.endswith("\")) {
      $dstFile = $dst + (get-childitem $file).Name
    } else {
      $dstFile = $dst
    }
    $this.waitForTools()
    try {
      copy-VMGuestFile -source $file -destination $dst -vm $this.vivm `
        -GuestUser $this.user -GuestPassword $this.password -force `
        -LocalToGuest -confirm:$false -ToolsWaitSecs 120 -EA Stop | out-null
    } catch {
      addToResult "Fail - copy file to VM"
      endError
    }  
    addToResult "Success - copy file to VM"
  } -name copyFileToVm
  
  $vm | add-member -MemberType ScriptMethod -Value { ##restoreSnapshot
    Param($snapshot)    
    $ss = get-snapshot -vm $this.vivm -Server $this.server.viserver | where{$_.name -eq "$snapshot"}
    if (!$ss) {
      addToResult "Fail - find snapshot $snapshot"
      endExec
    } elseif ($ss.count -ne $null) {
      $ss = $ss[-1]
    }
    set-VM -vm $this.vivm -snapshot $ss -confirm:$false -Server $this.server.viserver | out-null
    $ss = get-snapshot -vm $this.vivm -Server $this.server.viserver | where{$_.name -eq "$snapshot"} 
    if ($ss.iscurrent -eq $true) {
      addToResult "Success - restore snapshot $snapshot"
    } else {
      addToResult "Fail - restore snapshot $snapshot"
      endExec
    }
  } -name restoreSnapshot
  
  $vm | add-member -MemberType ScriptMethod -Value { ##takeSnapshot
    Param($name,$description)

    $ss = get-snapshot -name $name -vm $this.vivm -Server $this.server.viserver
    
    if ($ss) {
      addToResult "Warning - snapshot $name already exists, deleting it..."
      remove-Snapshot -snapshot $ss -Confirm:$false
      
      $ss = get-snapshot -name $name -vm $this.vivm -Server $this.server.viserver
      if ($ss) {
        addToResult "Fail - delelet Snapshot $name"
        endExec
      } else {
        addToResult "Success - delelet Snapshot $name"
      }
    }
      
    if (!$description) {$description = "Created by Web Commander on " + (get-date)}
    $newSnapshot = new-snapshot -Name $name -Description $description -VM $this.vivm -Server $this.server.viserver -Confirm:$false
    if ($newSnapshot -ne $null) {
      addToResult "Success - create snapshot $name"
    } else {
      addToResult "Fail - create snapshot $name"
    }
  } -name takeSnapshot
  
  $vm | add-member -MemberType ScriptMethod -Value { ##removeSnapshot
    Param($snapshot)
    
    $ss = get-snapshot -vm $this.vivm -Server $this.server.viserver | where{$_.name -eq "$snapshot"}
    if (!$ss) {
      addToResult "Fail - find snapshot $snapshot"
      endExec
    } elseif ($ss.count -gt 1) {
      addToResult "Warn - find more than 1 snapshots named $snapshot"
      addToResult "Fail - delete snapshot $snapshot"
      endExec
    }
    
    try {
      get-snapshot -vm $this.vivm -name $snapshot -ea stop | remove-snapshot -confirm:$false -ea stop
    } catch {
      addToResult "Fail - delete snapshot $snapshot"
      endError
    }
    addToResult "Success - delete snapshot $snapshot"  
  } -name removeSnapshot
  
  $vm | add-member -MemberType ScriptMethod -Value { ##getIpv4
    $ip = (Get-VMGuest $this.vivm).IPAddress[0]
    return $ip
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
    return (Get-VMHost -Server $this.server.viserver -VM $this.name).name
  } -name getVmHost
  
  $vm | add-member -MemberType ScriptMethod -Value { ##linkClone
    Param($snapshot, $namePrefix, $number)  

    $sourceVM = $this.vivm | Get-View  
    $cloneFolder = $sourceVM.parent  
    $cloneSpec = new-object Vmware.Vim.VirtualMachineCloneSpec
    
    if ($snapshot) {
      $ss = get-snapshot -vm $this.vivm -name $snapshot -Server $this.server.viserver -ea silentlycontinue
      if(!$ss){
        addToResult "Fail - find snapshot $snapshot"
        endExec
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
        addToResult "Info - $cloneName is created"
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