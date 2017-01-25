function newVmWin {
  Param($server,$name,$guestUser,$guestPassword)

  $vm = newVm $server $name $guestUser $guestPassword
  
  $vm | add-member -MemberType ScriptMethod -Value { ##checkPs
    $cmd = 'Powershell -noprofile -command $PSVersionTable.PSVersion.major'
    [int]$psVer = $this.runScript($cmd, "Bat")
    if ($psVer[0] -ge 2) {
      addToResult "Info - Powershell $psVer is installed in target VM"
      return $true
    } 
    else {
      addToResult "Info - Powershell is NOT installed in target VM"
      return $false
    }
  } -name checkPs
  
  $vm | add-member -MemberType ScriptMethod -Value { ##installPs
    if ($this.checkPs()) {
      return
    }
    $gosName = (Get-VMGuest $this.vivm).OSFullName

    if ($gosName -like "* XP *(32-bit)") {
      $this.copyFileToVm("..\postinstall\dotNet\netfx20sp1_x86.exe","c:\temp\")
      $this.copyFileToVm("..\postinstall\powershell\X86-en-windowsxp-kb968930-x86-eng.exe","c:\temp\")
      $cmd = @"
c:\temp\netfx20sp1_x86.exe /qb /norestart
c:\temp\X86-en-windowsxp-kb968930-x86-eng.exe /quiet /norestart
"@
    } 
    elseif ($gosName -like "* XP *(64-bit)")
    {
      $this.copyFileToVm("..\postinstall\dotNet\netfx20sp1_x64.exe","c:\temp\")
      $this.copyFileToVm("..\postinstall\powershell\WindowsServer2003.WindowsXP-KB926139-v2-x64-ENU.exe","c:\temp\")
      $cmd = @"
c:\temp\netfx20sp1_x64.exe /qb /norestart
c:\temp\WindowsServer2003.WindowsXP-KB926139-v2-x64-ENU.exe /passive /norestart
"@
    }
    elseif ($gosName -like "* 2003 *(32-bit)")
    {
      $this.copyFileToVm("..\postinstall\dotNet\netfx20sp1_x86.exe","c:\temp\")
      $this.copyFileToVm("..\postinstall\powershell\X86-en-windowsserver2003-kb968930-x86-eng.exe","c:\temp\")
      $cmd = @"
c:\temp\netfx20sp1_x86.exe /qb /norestart
c:\temp\X86-en-windowsserver2003-kb968930-x86-eng.exe /quiet /norestart
"@
    }
    elseif ($gosName -like "* 2003 *(64-bit)")
    {
      $this.copyFileToVm("..\postinstall\dotNet\netfx20sp1_x64.exe","c:\temp\")
      $this.copyFileToVm("..\postinstall\powershell\AMD64-en-windowsserver2003-kb968930-x64-eng.exe","c:\temp\")
      $cmd = @"
c:\temp\netfx20sp1_x64.exe /qb /norestart
c:\temp\AMD64-en-windowsserver2003-kb968930-x64-eng.exe /quiet /norestart
"@
    }
    elseif (($gosName -like "* Vista *(32-bit)") `
      -or ($gosName -like "* 2008 *(32-bit)"))
    {
      $this.copyFileToVm("..\postinstall\powershell\X86-all-windows6.0-kb968930-x86.msu","c:\temp\")
      $cmd = "c:\temp\X86-all-windows6.0-kb968930-x86.msu /quiet /norestart"
    }
    elseif (($gosName -like "* Vista *(64-bit)") `
      -or ($gosName -like "* 2008 *(64-bit)"))
    {
      $this.copyFileToVm("..\postinstall\powershell\AMD64-all-windows6.0-kb968930-x64.msu","c:\temp\")
      $cmd = "c:\temp\AMD64-all-windows6.0-kb968930-x64.msu /quiet /norestart"
    }
    
    cmd += @"
    
powershell set-executionpolicy unrestricted -confirm:`$false
"@
    $this.runScript($cmd,"Bat")
    if ($this.checkPs()) {
      addToResult "Succeed - install Powershell in the target VM"
    } else {
      addToResult "Fail - install Powershell in the target VM"
      endExec
    }
  } -name installPs
  
  $vm | add-member -MemberType ScriptMethod -Value { ##checkPsRemote
    $cred = new-object -typeName System.management.automation.pscredential -argumentList $this.user, (ConvertTo-SecureString $this.password -asPlainText -Force)
    $version = invoke-command -scriptblock {$PSVersionTable.PSVersion.major} -computername $this.getIPv4() -cred $cred -wa 0 -EA SilentlyContinue
    if ($version -ge 2) {
      addToResult "Info - Powershell $version is installed in target VM"
      addToResult "Info - Powershell Remoting is enabled in target VM"
      return $true
    } else {
      addToResult "Info - Powershell Remoting is NOT enabled in target VM"
      return $false
    }
  } -name checkPsRemote
  
  $vm | add-member -MemberType ScriptMethod -Value { ##enablePsRemote
    if ($this.checkPsRemote()) {
      return
    }
    $this.installPs()
    $cmd = @'
if([environment]::OSVersion.version.Major -lt 6) { 
$regkey = "HKLM:\system\currentcontrolset\control\lsa"
set-itemproperty -path $regkey -name forceguest -value 0
return } 
if(1,3,4,5 -contains (Get-WmiObject win32_computersystem).DomainRole) { return } 
$networkListManager = [Activator]::CreateInstance([Type]::GetTypeFromCLSID([Guid]"{DCB00C01-570F-4A9B-8D69-199FDBA5723B}")) 
$connections = $networkListManager.GetNetworkConnections() 
$connections | % {$_.GetNetwork().SetCategory(1)}
'@
    $this.runScript($cmd,"Powershell")
    $cmd = @'
try {enable-psremoting -force -ea SilentlyContinue
Set-Item WSMan:\localhost\Shell\MaxMemoryPerShellMB 1024 -wa 0 -ea SilentlyContinue}
catch { write-output "Error occurred to enable-psremoting"}
sc.exe config winrm start= auto | out-null
netsh advfirewall firewall set rule name="Windows Remote Management (HTTP-In)" new profile=any remoteip=any
'@
    $this.runScript($cmd,"Powershell")
  } -name enablePsRemote
  
  $vm | add-member -MemberType ScriptMethod -Value { ##enableCredSSP
    $cmd = @'
try {Enable-WSManCredSSP -role server -force -ea SilentlyContinue | out-null}
catch { echo "CredSSP is not supported on Windows XP or 2003"}
'@
    $this.runScript($cmd,"Powershell")
  } -name enableCredSSP
  
  $vm | add-member -MemberType ScriptMethod -Value { ##renewIp
    $cmd = @'
$ip = ipconfig | select-string ("ipv4 address","ip address")
$ip = $ip.line.split(": ")[-1]
if ($ip.startswith("169.254")){
$ip = ipconfig /renew
$ip = $ip | select-string ("ipv4 address","ip address")
$ip = $ip.line.split(": ")[-1]
}
$ip
'@  
    $ip = $this.runScript($cmd,"Powershell")
    if ($ip.startswith("169.254")) {
      addToResult "Fail - renew VM IP $ip"
      endExec
    } else {
      addToResult "Success - renew VM IP $ip"
      return $ip.trim()
    }  
  } -name renewIp
  
  return $vm
}