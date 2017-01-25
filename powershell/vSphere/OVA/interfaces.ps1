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
    Deploy

  .DESCRIPTION
    This command deploys an OVA to ESX or VC.
    
  .FUNCTIONALITY
    OVA
  
  .NOTES
    AUTHOR: Jerry Liu
    EMAIL: liuj@vmware.com
#>

Param (
##################### Start general parameters #####################
  [parameter(
    HelpMessage="IP or FQDN of ESX or VC server to which the OVA will be deployed"
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
    HelpMessage="Name of datastore to which the OVA will be deployed"
  )]
  [string]
    $datastore, 
  
  [parameter(
    HelpMessage="Storage format"
  )]
  [ValidateSet(
    "Thin",
    "Thick",
    "EagarZeroedThick"
  )]
  [string]
    $storageFormat="Thin",
    
  [parameter(
    HelpMessage="Name of Virtual Machine Port Group to which the OVA will connect"
  )]
  [string]
    $portGroup,
    
  [parameter(
    HelpMessage="Advanced properties, such as --prop:vami.hostname=myvmname"
  )]
  [string]
    $advancedProperty, 
    
  [parameter(
    Mandatory=$true,
    HelpMessage="URL of the OVA"
  )]
  [string]
    $ovaUrl, 
    
  [parameter(
    Mandatory=$true,
    HelpMessage="Name of the VM to be deployed"
  )]
  [string]
    $vmName,
##################### Start deployToEsx parameters #####################
  [parameter(parameterSetName="deployToEsx")]
  [Switch]
    $deployToEsx,
##################### Start deployToVc parameters #####################
  [parameter(
    parameterSetName="deployToVc",
    HelpMessage="Name of datacenter to which the OVA will be deployed"
  )]
  [string]
    $datacenter,
    
  [parameter(
    parameterSetName="deployToVc",
    HelpMessage="Name of cluster to which the OVA will be deployed"
  )]
  [string]  
    $cluster, 
    
  [parameter(
    parameterSetName="deployToVc",
    HelpMessage="Name of ESX host to which the OVA will be deployed"
  )]
  [string]  
    $esxHost, 
    
  [parameter(parameterSetName="deployToVc")]
  [Switch]
    $deployToVc
)

. .\utils.ps1
. .\vsphere\object.ps1

switch ($pscmdlet.parameterSetName) {
  "deployToEsx" {
    if (!$datastore -or !$portGroup) {
      add-pssnapin vm* -ea silentlyContinue | out-null
      connect-viserver $serverAddress -user $serverUser -password $serverPassword | out-null
      if (!$datastore) { $datastore = (get-datastore | sort freespacegb -desc | select -first 1).name } 
      if (!$portGroup) { $portgroup = (get-virtualportgroup | ?{$_.port -eq $null} | select -first 1).name }
    }
    $cmd = "& `"C:\Program Files\VMware\VMware OVF Tool\ovftool.exe`" --acceptAllEulas --allowAllExtraConfig --hideEula --noSSLVerify --datastore=`"$datastore`" --diskMode=$storageFormat --network=`"$portGroup`" --name=`"$vmName`""
    if ($advancedProperty) {
      $advancedProperty = $advancedProperty.replace("`r`n"," ")
      $cmd += " $advancedProperty"
    }
    $viPath = "vi://$serverUser`:$serverPassword@$serverAddress/host/"
    $viPath += "$host"
    $cmd += " $ovaUrl '$viPath'"
    $output = invoke-expression $cmd
    if ($output -contains "Completed successfully") {
      addToResult "Success - deploy OVA"
    } else {
      addToResult "Fail - deploy OVA"
      addToResult $output "raw"
    } 
  }
  "deployToVc" { 
    if (!datacenter -or !$datastore -or !$portGroup -or !$esxHost) {
      add-pssnapin vm* -ea silentlyContinue | out-null
      connect-viserver $serverAddress -user $serverUser -password $serverPassword | out-null
      if (!$datacenter) { 
        $container = get-datacenter | select -first 1 
      } else {
        $container = get-datacenter $datacenter
      }
      if ($cluster) { $container = get-cluster $cluster -location $container}
      if (!$esxHost) { 
        $vmhost = get-vmhost -location $container | select -first 1
      } else {
        $vmhost = get-vmhost -name $esxHost -location $container
      }
      if (!$datastore) { $datastore = (get-datastore -vmhost $vmhost | sort freespacegb -desc | select -first 1).name } 
      if (!$portGroup) { $portgroup = (get-virtualportgroup -vmhost $vmhost | ?{$_.port -eq $null} | select -first 1).name }
    }

    $cmd = "& `"C:\Program Files\VMware\VMware OVF Tool\ovftool.exe`" --acceptAllEulas --allowAllExtraConfig --hideEula --noSSLVerify --datastore=`"$datastore`" --diskMode=$storageFormat --network=`"$portGroup`" --name=`"$vmName`""
    if ($advancedProperty) {
      $advancedProperty = $advancedProperty.replace("`r`n"," ")
      $cmd += " $advancedProperty"
    }
    $viPath = "vi://$vcUser`:$vcPassword@$vcAddress/$datacenter/host/"
    if($cluster) {
      $viPath += "$cluster/"
    }
    if($esxHost) {
      $viPath += "$esxHost/"
    } else {
      $viPath += "$($vmhost.name)/"
    }
    $cmd += " `"$ovaUrl`" `"$viPath`""
    writeCustomizedMsg "Info - start to deploy OVA"
    try {
      $output = invoke-expression $cmd -EA stop
      if ($output -notcontains "Completed successfully") {
        throw $output
      } else {
        addToResult "Success - deploy OVA"
      }
    } catch {
      addToResult "Fail - deploy OVA"
      endError
    } 
  }
}
