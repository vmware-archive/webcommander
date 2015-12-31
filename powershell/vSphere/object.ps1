function newServer {
  
  Param(
    [parameter(ValueFromPipeline=$True)]
    $address, 
    
    $user, 
    $password
  )

  begin {
    add-pssnapin vmware.vimautomation.core -ea silentlycontinue
  }
  
  process {
    try {
      $viserver = connect-VIServer $address -user $user -password $password -NotDefault
      addToResult "Success - connect to server $address"
      addToResult "Info - server is of product line: $($viserver.productline.toUpper())"
    } catch {
      addToResult "Fail - connect to server $address"
      endError
    }

    $server = New-Object PSObject -Property @{
      address = $address
      user = $user
      password = $password
      viserver = $viserver
    }
    
    $server | add-member -MemberType ScriptMethod -value {
      param($vmName)
      $vm = get-vm $vmName -server $this.viserver |
        select Name, NumCpu, MemoryMB, ProvisionedSpaceGB, @{Name="State";Expression={$_.guest.state.tostring()}},`
        @{Name="IP";Expression={$_.guest.IPAddress[0]}},@{Name="OS";Expression={$_.guest.OSFullName}}
      addToResult $vm "dataset"
    } -name listVm
    
    $server | add-member -MemberType ScriptMethod -value {
      param($pgName)
      $pg = get-virtualportgroup -Server $this.viserver -name $pgName | 
        Select Name, VirtualSwitchName, VLanID, `
        @{Name="VMHost"; Expression={$_.VirtualSwitch.vmhost.name}}
      addToResult $pg "dataset"
    } -name listPortGroup
    
    $server | add-member -MemberType ScriptMethod -value {
      param($dsName)
      $ds = get-datastore -server $this.viserver -name $dsName |
        Select Name, @{Name="FreeSpaceGB";Expression={"{0:N2}" -f $_.FreeSpaceGB}},`
        @{Name="CapacityGB";Expression={"{0:N2}" -f $_.CapacityGB}}
      addToResult $ds "dataset"
    } -name listDatastore
    
    $server | add-member -MemberType ScriptMethod -value {
      param($rpName)
      $rp = get-resourcepool -Server $this.viserver -name $rpName | 
        select Name, ID, @{Name="Path";Expression={
          $r = $_
          $path = $r.name
          Do { 
            $parent = $r.parent
            $path = $parent.Name + "\" + $path
            $r = $parent
          } While ($parent)
          $path
        }} 
      addToResult $rp "dataset"
    } -name listResourcePool
    
    $server | add-member -MemberType ScriptMethod -value {
      param($vhName)
      $vh = get-VMHost -Server $this.viserver -name $vhName | 
        select Name,ConnectionState,PowerState,Manufacturer,Model,`
        NumCpu,CpuTotalMhz,CpuUsageMhz,LicenseKey,MemoryUsageGB,`
        MemoryTotalGB,Version
      addToResult $vh "dataset"
    } -name listVmHost
    
    $server | add-member -MemberType ScriptMethod -value {
      param($ntpServerAddress, $includeVm)
      get-vmhost -Server $this.viserver | % {
        try {
          $_ | add-vmhostNtpServer $ntpServerAddress -ea SilentlyContinue
          $_ | Get-VMHostFirewallException | where {$_.Name -eq "NTP client"} | `
            Set-VMHostFirewallException -Enabled:$true | out-null
          $_ | Get-VmHostService | ? {$_.key -eq "ntpd"} | Start-VMHostService | out-null
          $_ | Get-VmHostService | ? {$_.key -eq "ntpd"} | Set-VMHostService -policy "automatic" | out-null
          addToResult "Success - configure NTP settings for vmhost $($_.name)"
        } catch {
          addToResult "Fail - configure NTP settings for vmhost $($_.name)"
          endError
        }
      }
      if ($includeVm) {
        get-vm -Server $this.viserver | % {
          try {
            $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
            $spec.changeVersion = $_.ExtensionData.Config.ChangeVersion
            $spec.tools = New-Object VMware.Vim.ToolsConfigInfo
            $spec.tools.syncTimeWithHost = $true
            $_this = Get-View -Id $_.Id -server $this.viserver
            $null = $_this.ReconfigVM_Task($spec) 
            addToResult "Success - configure time sync settings for vm $($_.name)"
          } catch {
            addToResult "Fail - configure time sync settings for vm $($_.name)"
            endError
          }
        }
      }
    } -name syncTime
    
     $server | add-member -MemberType ScriptMethod -value {
      param($nfs,$readonly)
      $vmHosts = get-vmhost -server $this.viserver
      $vmHosts | Get-VMHostFirewallException -Name "NFS Client" | Set-VMHostFirewallException -Enabled:$true | out-null
      $vmHosts | Get-EsxCli | %{try{$_.network.firewall.ruleset.set($true, $true, "nfsClient")}catch{}} | out-null
      foreach ($esx in $vmHosts) {
        try {
          new-datastore -nfs -vmHost $esx -name $nfs.name -path $nfs.path -nfshost $nfs.host -readOnly:$readOnly -EA Stop
          addToResult "Success - mount NFS share on host $($esx.name)."
        } catch [VMware.VimAutomation.ViCore.Types.V1.ErrorHandling.AlreadyExists] {
          addToResult "Info - NFS share already exists on host $($esx.name)."
        } catch {
          addToResult "Fail - mount NFS share on host $($esx.name)."
          endStderr
        }
      }
    } -name mountNfs
    
    $server | add-member -MemberType ScriptMethod -value {
      param($nfsStoreName)
      $vmHosts = get-vmhost -server $this.viserver
      $datastore = get-datastore -server $this.viserver | ?{$_.type -eq "nfs"}
      if ($nfsStoreName) {$datastore = $datastore | ?{$_.name -like $nfsStoreName}}
      if ($datastore) {
        foreach ($esx in $vmHosts) {
          try {
            remove-datastore -vmhost $esx -datastore $datastore -confirm:$false
            addToResult "Success - remove NFS datastore on host $esx"
          } catch {
            addToResult "Fail - remove NFS datastore on host $esx"
            endError
          }
        }
      } else {
        addToResult "Info - no NFS datastore found"
      }
    } -name removeNfs
    
    $server | add-member -MemberType ScriptMethod -value {
      param($enable)
      $vmHosts = get-vmhost -server $this.viserver
      foreach ($h in $vmHosts) {
        try {
          if ($enable) {
            $h | Set-VMHostAdvancedConfiguration -Name Mem.ShareScanGHz -Value 4 -Confirm:$false | out-null
            addToResult "Success - enable page sharing for vmhost $($h.name)"
          } else {
            $h | Set-VMHostAdvancedConfiguration -Name Mem.ShareScanGHz -Value 0 -Confirm:$false | out-null
            addToResult "Success - disable page sharing for vmhost $($h.name)"
          }
        } catch {
          addToResult "Fail - set page sharing for vmhost $($h.name)"
          endError
        }  
      }
    } -name setPageSharing
    
    return $server
  }
  
  end {}
}