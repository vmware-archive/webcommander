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
    VM 

  .DESCRIPTION
    Virtual Machine
    
  .NOTES
    AUTHOR: Jian Liu
    EMAIL: whirls9@hotmail.com
#>

Param (
##################### Start general parameters #####################
  [parameter(
    Mandatory=$true,
    HelpMessage="IP or FQDN of the ESX or VC server hosting the VM"
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
    HelpMessage="Name of target VM. Support multiple values seperated by comma and also wildcard."
  )]
  [string]
    $vmName, 
##################### Start answerQuestion parameters #####################  
  [parameter(
    parameterSetName="answerQuestion",
    HelpMessage="The answer for the question. Default is 'cancel'."
  )]
  [string]
    $answer="cancel",
    
  [parameter(
    parameterSetName="answerQuestion",
    HelpMessage="Answer VM question"
  )]
  [Switch]
    $answerQuestion,
##################### Start delete parameters #####################    
  [parameter(
    parameterSetName="delete",
    HelpMessage="Delete VM from disk"
  )]
  [switch]
    $delete,
##################### Start poweroff parameters #####################    
  [parameter(
    parameterSetName="poweroff"
  )]
  [switch]
    $poweroff,
##################### Start poweroff parameters #####################    
  [parameter(
    parameterSetName="poweron"
  )]
  [switch]
    $poweron,
##################### Start poweroff parameters #####################    
  [parameter(
    parameterSetName="suspend"
  )]
  [switch]
    $suspend,
##################### Start poweroff parameters #####################    
  [parameter(
    parameterSetName="restart"
  )]
  [switch]
    $restart,
##################### Start addHardDisk parameters #####################    
  [parameter(
    parameterSetName="addHardDisk",
    Mandatory=$true,
    HelpMessage="Disk capacity in gigabytes (GB)"
  )]
  [string]
    $capacityGb,
  
  [parameter(
    parameterSetName="addHardDisk",
    HelpMessage="Number of disks to add. Default is 1."
  )]
  [string]
    $diskNumber="1",
  
  [parameter(
    parameterSetName="addHardDisk",
    HelpMessage="Storage format. Default is Thin."
  )]
  [ValidateSet(
    "Thin",
    "Thick",
    "EagarZeroedThick"
  )]
  [string]
    $storageFormat="Thin",
  
  [parameter(
    parameterSetName="addHardDisk",
    HelpMessage="Persistence mode, default is IndependentPersistent."
  )]
  [ValidateSet(
    "IndependentPersistent",
    "IndependentNonPersistent",
    "Persistent"
  )]
  [string]
    $persistence="IndependentPersistent",
  
  [parameter(
    parameterSetName="addHardDisk"
  )]
  [switch]
    $addHardDisk,
##################### Start setPortGroup parameters #####################    
  [parameter(
    parameterSetName="setPortGroup",
    Mandatory=$true,
    HelpMessage="Name of the port group"
  )]
  [string]
    $portGroup,
  
  [parameter(
    parameterSetName="setPortGroup",
    helpMessage="Add VM network card into specified port group"
  )]
  [switch]
    $setPortGroup,
##################### Start setMemorySize parameters #####################    
  [parameter(
    parameterSetName="setMemorySize",
    Mandatory=$true,
    HelpMessage="Memory size in gigabytes (GB)"
  )]
  [string]
    $memoryGb,
  
  [parameter(
    parameterSetName="setMemorySize"
  )]
  [switch]
    $setMemorySize,
##################### Start updateVmTools parameters #####################    
  [parameter(
    parameterSetName="updateVmTools"
  )]
  [switch]
    $updateVmTools,
##################### Start runScript parameters #####################
  [parameter(parameterSetName="runScript")]
  [parameter(parameterSetName="uploadFile")]
  [parameter(HelpMessage="User of target VM (default is administrator)")]
  [string]  
    $guestUser="administrator", 
    
  [parameter(parameterSetName="runScript")]
  [parameter(parameterSetName="uploadFile")]
  [parameter(HelpMessage="Password of guestUser")]
  [string]  
    $guestPassword=$env:defaultPassword, 
    
  [parameter(
    parameterSetName="runScript",
    Mandatory=$true,
    HelpMessage="Script text"
  )]
  [string]
    $scriptText,
    
  [parameter(
    parameterSetName="runScript",
    HelpMessage="Script type. Default is 'Bat'."
  )]
  [ValidateSet(
    "Bat",
    "Bash",
    "Powershell"
  )]
    $scriptType="Bat",
  
  [parameter(
    parameterSetName="runScript"
  )]
  [switch]
    $runScript,
##################### Start uploadFile parameters #####################    
  [parameter(parameterSetName="uploadFile")]
  [parameter(
    parameterSetName="setVmx",
    Mandatory=$true,
    HelpMessage="select a file"
  )]
  [string]
    $file,
  
  [parameter(
    parameterSetName="uploadFile",
    Mandatory=$true,
    HelpMessage="Destination path, such as c:\temp\"
  )]
  [string]
    $destination,
  
  [parameter(
    parameterSetName="uploadFile",
    helpMessage="upload file to VM"
  )]
  [switch]
    $uploadFile,
##################### Start getVmx parameters #####################    
  [parameter(
    parameterSetName="getVmx",
    helpMessage="get content of VMX file"
  )]
  [switch]
    $getVmx,
##################### Start setVmx parameters #####################    
  [parameter(
    parameterSetName="setVmx",
    helpMessage="set content of VMX file"
  )]
  [switch]
    $setVmx,
##################### Start listSnapshot parameters #####################    
  [parameter(
    parameterSetName="listSnapshot",
    helpMessage="List all snapshots of the VM"
  )]
  [switch]
    $listSnapshot,
##################### Start takeSnapshot parameters #####################    
  [parameter(parameterSetName="takeSnapshot")]
  [parameter(parameterSetName="restoreSnapshot")]
  [parameter(parameterSetName="removeSnapshot")]
  [parameter(helpMessage="Snapshot name")]
  [string]
    $ssName,
  
  [parameter(
    parameterSetName="takeSnapshot",
    helpMessage="Snapshot description"
  )]
  [string]
    $ssDescription,
    
  [parameter(
    parameterSetName="takeSnapshot"
  )]
  [switch]
    $takeSnapshot,
##################### Start restoreSnapshot parameters #####################    
  [parameter(
    parameterSetName="restoreSnapshot"
  )]
  [switch]
    $restoreSnapshot,
##################### Start removeSnapshot parameters #####################    
  [parameter(
    parameterSetName="removeSnapshot"
  )]
  [switch]
    $removeSnapshot,
##################### Start getIp parameters #####################    
  [parameter(
    parameterSetName="getIp",
    helpMessage="Get VM IP address"
  )]
  [switch]
    $getIp
)

. .\utils.ps1
. .\vsphere\object.ps1
. .\vsphere\vm\object.ps1

$server = newServer $serverAddress $serverUser $serverPassword
$vivmList = getVivmList $vmName $server
switch ($pscmdlet.parameterSetName) {
  "answerQestion" { 
    $vivmList | % {
      try {
        Get-VMQuestion -vm $_ | Set-VMQuestion -Option $answer -confirm:$false -ea Stop
        addToResult "Success - answer VM question for $($_.name)"
      } catch {
        addToResult "Fail - answer VM question for $($_.name)"
        addError
      }
    } 
  }
  "delete" {
    $vivmList | % {
      try {
        remove-vm -vm $_ -DeleteFromDisk:$true -confirm:$false -EA Stop
        addToResult "Success - delete VM $($_.name)"
      } catch {
        addToResult "Fail - delete VM $($_.name)"
        addError
      }
    } 
  }
  "setMemorySize" {
    $vivmList | % {
      try {
        set-vm -vm $_ -memoryGb $memoryGb -confirm:$false -ea Stop
        addToResult "Success - set memory for VM $($_.name)"
      } catch {
        addToResult "Fail - set memory for VM $($_.name)"
        addError
      }
    }
  }
  "addHardDisk" {
    $vivmList | % {
      $vm = $_
      (1..$diskNumber) | % {
        try {
          New-HardDisk -CapacityGB $capacityGb -StorageFormat $storageFormat -Confirm:$false `
            -VM $vm -Persistence $persistence -ea Stop
          addToResult "Success - add disk $_ to vm $vm.name"
        } catch {
          addToResult "Fail - add disk $_ to vm $vm.name"
          addError
        }
      }
    }
  }
  "getVmx" {
    $vivmList | % { 
      $vm = newVm $server $_.name
      $vm.getVmx()
    }
  }
  "setVmx" {
    $vivmList | % { 
      $vm = newVm $server $_.name
      $vm.setVmx($file)
    }
  }
  "runScript" {
    $vivmList | % { 
      try {
        $output = Invoke-VMScript -vm $_ -ScriptText $scriptText -ScriptType $scriptType -GuestUser $guestUser `
          -GuestPassword $guestPassword -confirm:$false -EA Stop
        addToResult "Success - run script on VM $($_.name)"
        addToResult $output.scriptoutput "raw"
      } catch {
        addToResult "Fail - run script on VM $($_.name)"
        addError
      }
    }
  }
  "restart" {
    $vivmList | % { 
      try {
        restart-vmguest -vm $_ -confirm:$false -EA Stop
        addToResult "Success - restart VM $($_.name)"
      } catch {
        addToResult "Fail - restart VM $($_.name)"
        addError
      }  
    }
  }
  "setPortGroup" {
    $vivmList | % {
      try {
        $pg = get-virtualPortGroup -name $portGroup -vmHost $_.host -ea stop
        Get-NetworkAdapter -vm $_ | Set-NetworkAdapter -PortGroup $pg -confirm:$false -ea stop
        addToResult "Success - set VM network port group on $($_.name)"
      } catch {
        addToResult "Fail - set VM network port group on $($_.name)"
        addError
      }
    } 
  }
  "poweroff" {
    $vivmList | % { 
      if ($_.PowerState -ne "PoweredOff") {
        try {
          stop-vm -vm $_ -confirm:$false -runAsync:$false -EA Stop
          addToResult "Success - shutdown VM $($_.name)"
        } catch {
          addToResult "Fail - shutdown VM $($_.name)"
          addError
        }
      } else {
        addToResult "Info - VM $($_.name) is already powered off"
      }
    } 
  }
  "poweron" {
    $vivmList | % { 
      if ($_.PowerState -ne "PoweredOn") {
        try {
          Start-VM -vm $_ -confirm:$false -runAsync:$false -ea stop
          addToResult "Success - start VM $($_.name)"
        } catch {
          addToResult "Fail - start VM $($_.name)"
          addError
        }
      } else {
        addToResult "Info - VM $($_.name) is already powered on"
      }
    } 
  }
  "suspend" {
    $vivmList | % { 
      try {  
        Suspend-VM -vm $_ -confirm:$false -EA stop
        addToResult "Success - suspend VM $($_.name)"
      } catch {
        addToResult "Fail - suspend VM $($_.name)"
        addError
      }
    } 
  }
  "uploadFile" {
    $vivmList | % { 
      try {
        copy-VMGuestFile -vm $_ -destination $destination -localToGuest -GuestUser $guestUser `
          -GuestPassword $guestPassword -source $file -confirm:$false -ToolsWaitSecs 120 -EA Stop
        addToResut "Success - copy file to VM $($_.name)"
      } catch {
        addToResult "Fail - copy file to VM $($_.name)"
        addError
      }
    } 
  }
  "updateVmTools" {
    $vivmList | % { 
      try {
        Update-Tools -vm $_ -EA Stop
        addToResult "Success - update VMware Tools for VM $($_.name)"
      } catch {
        addToResult "Fail - update VMware Tools for VM $($_.name)"
        addError
      }
    } 
  }
  "listSnapshot" {
    $vivmList | % { 
      try {
        $snapshots = get-snapshot -vm $_ -EA Stop | select vm, name, description, powerstate, iscurrent, parent, children
        addToResult "Success - get snapshots of VM $($_.name)"
        if ($snapshots) {addToResult $snapshots "dataset"}
        else {addToResult "Info - VM $($_.name) has no snapshot"}
      } catch {
        addToResult "Fail - get snapshots of VM $($_.name)"
        addError
      }
    } 
  }
  "takeSnapshot" {
    $vivmList | % { 
      $vm = newVm $server $_.name
      $vm.stop()
      Get-FloppyDrive -VM $vm.vivm | Set-FloppyDrive -NoMedia -Confirm:$False
      Get-CDDrive -VM $vm.vivm | Set-CDDrive -NoMedia -Confirm:$False   
      $vm.takeSnapshot($ssName,$ssDescription)
    } 
  }
  "restoreSnapshot" {
    $vivmList | % { 
      $vm = newVm $server $_.name   
      $vm.restoreSnapshot($ssName)
    } 
  }
  "removeSnapshot" {
    $vivmList | % { 
      $vm = newVm $server $_.name 
      $vm.removeSnapshot($ssName)
    } 
  }
  "getIp" {
    $vivmList | % { 
      if ($_.guest.IPAddress) {
        $ip = $_.guest.IPAddress[0]
        addToResult "Sucess - find IP of VM $($_.name)"
        addToResult $ip "raw"
      } else {
        addToResult "Fail - find IP of VM $($_.name)"
      }
    } 
  }
}
