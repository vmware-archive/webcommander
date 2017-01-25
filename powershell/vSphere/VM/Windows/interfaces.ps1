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
    Windows VM

  .DESCRIPTION
    Windows Virtual Machine
    
  .FUNCTIONALITY
    VM
    
  .NOTES
    AUTHOR: Jerry Liu
    EMAIL: liuj@vmware.com
#>

Param (
##################### Start general parameters #####################
  [parameter(
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
    HelpMessage="Name of target VM. Support multiple values seperated by comma."
  )]
  [string]
    $vmName, 
  
  [parameter(
    HelpMessage="User of target machine (default is administrator)"
  )]
  [string]  
    $guestUser="administrator", 
    
  [parameter(
    HelpMessage="Password of guestUser"
  )]
  [string]  
    $guestPassword=$env:defaultPassword,
##################### Start enablePsRemoting parameters #####################
  [parameter(
    parameterSetName="enablePsRemoting"
  )]
  [switch]
    $enablePsRemoting,
##################### Start renewIp parameters #####################
  [parameter(
    parameterSetName="renewIp"
  )]
  [switch]
    $renewIp
)

. .\utils.ps1
. .\vsphere\object.ps1
. .\vsphere\vm\utils.ps1
. .\vsphere\vm\object.ps1
. .\vsphere\vm\windows\object.ps1

$server = newServer $serverAddress $serverUser $serverPassword
$vivmList = getVivmList $vmName $server
switch ($pscmdlet.parameterSetName) {
  "enablePsRemoting" { 
    $vivmList | % {
      $vm = newVmWin $server $_.name $guestUser $guestPassword
      $vm.waitForTools() 
      $vm.enablePsRemote()
    } 
  }
  "renewIp" {
    $vivmList | % {
      $vm = newVmWin $server $_.name $guestUser $guestPassword
      $vm.waitForTools() 
      $vm.renewIp()
    } 
  }
}
