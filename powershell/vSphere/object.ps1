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
      $vm = get-vm $vmName -server $this.viserver
      $folder = $vm.folder
      $path = "/" + $folder.name + "/" + $vmName
      while($folder.Parent){
        $folder = $folder.Parent
        $path = "/" + $folder.Name + $path
      }
      addToResult "Info - VM path on server is $path"
      return $path
    } -name getVmPath   
    
    $server | add-member -MemberType ScriptMethod -value {
      param($pgName)
      $pg = @()
      get-virtualportgroup -Server $this.viserver -name $pgName | % {
        $pg += @{
          "Name" = $_.name;
          "VMHost" = $_.VirtualSwitch.vmhost.name;
          "VirtualSwitchName" = $_.VirtualSwitchName;
          "VLanID" = $_.VLanID
        }
      }
      addToResult $pg "dataset"
    } -name listPortGroup
    
    $server | add-member -MemberType ScriptMethod -value {
      param($dsName)
      $ds = @()
      get-datastore -server $this.viserver -name $dsName | % {
        $ds += @{
          "Name" = $_.name;
          "FreeSpaceGB" = "{0:N2}" -f $_.FreeSpaceGB;
          "CapacityGB" = "{0:N2}" -f $_.CapacityGB
        }
      }
      addToResult $ds "dataset"
    } -name listDatastore
    
    $server | add-member -MemberType ScriptMethod -value {
      param($rpName)
      $rp = @()
      get-resourcepool -Server $this.viserver -name $rpName | % {
        $r = $_
        $path = $r.name
        Do { $parent = $r.parent
          $path = $parent.Name + "\" + $path
          $r = $parent
        } While ($parent)
        $rp += @{
          "Name" = $_.name;
          "ID" = $_.id;
          "Path" = $path
        }
      }
      addToResult $rp "dataset"
    } -name listResourcePool
    
    return $server
  }
  
  end {}
}