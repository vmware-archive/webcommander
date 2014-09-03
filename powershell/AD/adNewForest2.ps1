<#
Copyright (c) 2012-2014 VMware, Inc.

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

## Author: Jerry Liu, liuj@vmware.com

Param ($domainName, $netbiosName, $forestMode, $safeModePassword)

# set static IP address 
# $ipaddress = "192.168.0.225"
# $ipprefix = "24"
# $ipgw = "192.168.0.1"
# $ipdns = "192.168.0.225"
# $ipif = (Get-NetAdapter).ifIndex
# New-NetIPAddress -IPAddress $ipaddress -PrefixLength $ipprefix -InterfaceIndex $ipif -DefaultGateway $ipgw

# rename the computer
# $newname = "dc8508"
# Rename-Computer -NewName $newname -force

#install features
$featureLogPath = "c:\temp\featurelog.txt"
New-Item $featureLogPath -ItemType file -Force
$addsTools = "RSAT-AD-Tools"
Add-WindowsFeature $addsTools
Get-WindowsFeature | Where installed >>$featureLogPath

# restart the computer
# Restart-Computer

# Install AD DS, DNS and GPMC
# start-job -Name addFeature -ScriptBlock {
Add-WindowsFeature -Name "ad-domain-services" -IncludeAllSubFeature -IncludeManagementTools
Add-WindowsFeature -Name "dns" -IncludeAllSubFeature -IncludeManagementTools
Add-WindowsFeature -Name "gpmc" -IncludeAllSubFeature -IncludeManagementTools 
#}
# Wait-Job -Name addFeature
Get-WindowsFeature | Where installed >>$featureLogPath

# Create New Forest, add Domain Controller
Import-Module ADDSDeployment
Install-ADDSForest -CreateDnsDelegation:$false `
	-SafeModeAdministratorPassword (ConvertTo-SecureString $safeModePassword -asPlainText -Force) `
	-DatabasePath "C:\Windows\NTDS" `
	-DomainMode $forestMode `
	-DomainName $domainName `
	-DomainNetbiosName $netBiosName `
	-ForestMode $forestMode `
	-InstallDns:$true `
	-LogPath "C:\Windows\NTDS" `
	-NoRebootOnCompletion:$false `
	-SysvolPath "C:\Windows\SYSVOL" `
	-Force:$true