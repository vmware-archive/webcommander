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
    vSphere 

  .DESCRIPTION
    ESXi and vCenter
    
  .NOTES
    AUTHOR: Jian Liu
    EMAIL: whirls9@hotmail.com
#>

Param (
##################### Start general parameters #####################
  [parameter(
    Mandatory=$true,
    HelpMessage="IP or FQDN of ESX or VC server. Support multiple values seperated by comma."
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
##################### Start listPortGroup parameters #####################  
  [parameter(
    parameterSetName="listPortGroup",
    HelpMessage="This method lists port groups on VC or ESX"
  )]
  [Switch]
    $listPortGroup,
##################### Start listDatastore parameters #####################    
  [parameter(
    parameterSetName="listDatastore",
    HelpMessage="This method lists data stores on VC or ESX"
  )]
  [Switch]
    $listDatastore,
##################### Start listResourcePool parameters ##################### 
  [parameter(
    parameterSetName="listResourcePool",
    HelpMessage="This method lists data stores on VC or ESX"
  )]
  [Switch]
    $listResourcePool,
##################### Start listVirtualMachine parameters #####################        
  [parameter(
    parameterSetName="listVirtualMachine",
    HelpMessage="This method lists virtual machines on VC or ESX"
  )]
  [Switch]
    $listVirtualMachine,
##################### Start listVmHost parameters #####################    
  [parameter(
    parameterSetName="listVmHost",
    HelpMessage="This method lists VM hosts on VC or ESX"
  )]
  [Switch]
    $listVmHost,
##################### Start syncTime parameters #####################   
  [parameter(
    parameterSetName="syncTime",
    Mandatory=$true,
    HelpMessage="IP or FQDN of the NTP server"
  )]
  [string]
    $ntpServerAddress,
    
  [parameter(
    parameterSetName="syncTime",
    HelpMessage="Whether or not to sync time on VM"
  )]
  [ValidateSet(
    "false",
    "true"
  )]
  [string]
    $includeVm="false",
   
  [parameter(
    parameterSetName="syncTime",
    HelpMessage="This method synchronizes ESXi time to NTP and VM time to host"
  )]
  [Switch]
    $syncTime,
##################### Start mountNfsDatastore parameters #####################  
  [parameter(
    parameterSetName="mountNfsDatastore",
    Mandatory=$true,
    HelpMessage="NFS stores to mount in form of 'datastore name : NFS host : path'. Support multiple values. Each entry per line."
  )]
  [string]
    $datastoreList,
    
  [parameter(
    parameterSetName="mountNfsDatastore",
    HelpMessage="Mount NFS read only"
  )]
  [ValidateSet(
    "false",
    "true"
  )]
    $readOnly="false",
    
  [parameter(
    parameterSetName="mountNfsDatastore",
    HelpMessage="This method mounts NFS shared storage onto ESX"
  )]
  [Switch]
    $mountNfsDatastore,
##################### Start removeNfsDatastore parameters #####################   
  [parameter(
    parameterSetName="removeNfsDatastore",
    Mandatory=$true,
    HelpMessage="Name of NFS datastore to remove"
  )]
  [string]
    $nfsDatastoreName,
    
  [parameter(
    parameterSetName="removeNfsDatastore",
    HelpMessage="This method removes NFS shared storage from ESX"
  )]
  [Switch]
    $removeNfsDatastore,
##################### Start setInterVmPageSharing parameters #####################    
  [parameter(
    parameterSetName="setInterVmPageSharing",
    Mandatory=$true,
    HelpMessage="Enable inter-vm transparent page sharing"
  )]
  [ValidateSet(
    "false",
    "true"
  )]
  [string]
    $enable,
    
  [parameter(
    parameterSetName="setInterVmPageSharing",
    HelpMessage="This method sets inter-VM transparent page sharing on ESX or vCenter server."
  )]
  [Switch]
    $setInterVmPageSharing
)

. .\utils.ps1
. .\vsphere\object.ps1

$serverList = $serverAddress.split(",") | %{$_.trim()} | newServer -user $serverUser -password $serverPassword
switch ($pscmdlet.parameterSetName) {
  "listVirtualMachine" { 
    $serverList | % { $_.listVm("*") } 
  }
  "listPortGroup" { 
    $serverList | % { $_.listPortGroup("*") } 
  }
  "listDatastore" {
    $serverList | % { $_.listDatastore("*") } 
  }
  "listResourcePool" {
    $serverList | % { $_.listResourcePool("*") }
  }
  "listVmHost" {
    $serverList | % { $_.listVmHost("*") }
  }
  "syncTime" {
    $serverList | % { $_.syncTime($ntpServerAddress, [boolean]$includeVm) }
  }
  "mountNfsDatastore" {
    foreach ($line in $datastoreList) {
      $store = $line.split(':').trim()
      $nfs = @{
        "Name" = $store[0];
        "Host" = $store[1];
        "Path" = $store[2]
      }
      $serverList | % { $_.mountNfs($nfs, [boolean]$readOnly) }
    }
  }
  "removeNfsDatastore" {
    $serverList | % { $_.removeNfs($nfsDatastoreName) } 
  }"setInterVmPageSharing" {
    $serverList | % { $_.setPageSharing([boolean]$enable) } 
  }
  
}
