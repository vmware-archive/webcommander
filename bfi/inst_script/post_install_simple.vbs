On Error Resume next

Set colNamedArguments = WScript.Arguments.Named

staticIp = colNamedArguments.Item("staticIp")

Const HKCU=&H80000001 'HKEY_CURRENT_USER
Const HKLM=&H80000002 'HKEY_LOCAL_MACHINE
 
Const REG_SZ=1
Const REG_EXPAND_SZ=2
Const REG_BINARY=3
Const REG_DWORD=4
Const REG_MULTI_SZ=7
 
Const HKCU_IE_PROXY = "Software\Microsoft\Windows\CurrentVersion\Internet Settings"
Set oReg=GetObject("winmgmts:!root/default:StdRegProv")
Set objWMIService = GetObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")

Set FS = CreateObject("Scripting.FileSystemObject")
Set wshShell = WScript.CreateObject ("WSCript.shell")
set wshEnv = wshShell.Environment("PROCESS")
wshEnv("SEE_MASK_NOZONECHECKS") = 1

Function upgradeTools()
	Wscript.Echo "Upgrading VMware Tools..."
	cmdline = "a:\upgrader.exe -p ""/s /v/qn"""
	
	set process = wshshell.Exec(cmdline)
	'wscript.sleep(120000)
	
	do while process.status = 0	
			'wscript.sleep(5000)
			'wshshell.appactivate "vmware tools"
			wscript.sleep(5000)
			findwin = wshshell.appactivate("vmware product installation")
			if findwin = true Then
				wscript.sleep(5000)
				wshshell.sendkeys "{tab}"
				wscript.sleep(5000)
				wshshell.sendkeys "{enter}"
			end if
	loop
	
	Wscript.Echo "...Done!"
End Function 

Function GetNicInfo(strInfo)
	Set objWMIService = GetObject("winmgmts:\\.\root\cimv2")
	Set colItems = objWMIService.ExecQuery("Select * from Win32_NetworkAdapterConfiguration Where IPEnabled = True",,48)
	For Each objItem in colItems
		select case strInfo
			case "gateway"
				collection = objItem.DefaultIPGateway
			case "subnet"
				collection = objItem.IPSubnet
			case "ip"
				collection = objItem.IPAddress
			case "dns"
				collection = objItem.DNSServerSearchOrder
		end select
		if (not IsNull(collection)) then
			For Each objElement In collection
				GetNicInfo = objElement
				exit Function
			Next
		end if
	Next
End Function

Function setStaticIP(strIP)
	if strIP = "DHCP" Then
		exit Function
	End if
	
	Set objWMIService = GetObject("winmgmts:\\.\root\cimv2")
	Set colNetAdapters = objWMIService.ExecQuery("Select * from Win32_NetworkAdapterConfiguration where IPEnabled=TRUE")

	strIPAddress = Array(strIP)
	strSubnetMask = Array(GetNicInfo("subnet"))
	strGateway = Array(GetNicInfo("gateway"))
	strGatewayMetric = Array(1)
	strDnsServer = Array(GetNicInfo("dns"))
 
	For Each objNetAdapter in colNetAdapters
		errEnable = objNetAdapter.EnableStatic(strIPAddress, strSubnetMask)
		errGateways = objNetAdapter.SetGateways(strGateway, strGatewaymetric)
		If errEnable = 0 Then
			WScript.Echo "The IP address has been changed."
			If dnsServerAddress = "DHCP" Then
				objNetAdapter.SetDNSServerSearchOrder(strDnsServer)
			End If
		Else
			WScript.Echo "The IP address could not be changed."
		End If
	Next
End Function

setStaticIP(staticIp)
upgradeTools()