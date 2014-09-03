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

Param ($updateServer,$severity,$emailTo,$uvsId)

#$regKey = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
#Set-ItemProperty -path $regKey -name WUServer -value http://10.117.0.25:8530
#Set-ItemProperty -path $regKey -name WUStatusServer -value http://10.117.0.25:8530

function notifyUvs {
	param ($id, $result)
	#$ie = new-object -com "InternetExplorer.Application"
	#$ie.visible = $true
	#$ie.navigate("http://racetrack.eng.vmware.com/uvsjobnotify.php?id=$id&result=$result")
	$wc = new-object system.net.webclient
	$wc.downloadstring("http://racetrack.eng.vmware.com/uvsjobnotify.php?id=$id&result=$result")	
}

function sendMail {
	param ($receiver, $content, $attachment)
	$cmd = "send-mailmessage -to $receiver -from webCommander@vmware.com -subject 'webCommander notification'" +
			" -smtpServer smtp.vmware.com -body '" + $content + "'"
	if($attachment) { $cmd += " -attachment $attachment" }
	$cmd += " -ea SilentlyContinue"
	invoke-expression $cmd
}

start-sleep 30 # wait for the VM to initialize network
$hostIP = Get-WmiObject Win32_NetworkAdapterConfiguration | ? {$_.IPAddress} | Select IPaddress | fc -expand CoreOnly | findstr [0]
$hostIP = $hostIP[0]
$hostName = hostname

$objServiceManager = New-Object -ComObject "Microsoft.Update.ServiceManager"
$objSession = New-Object -ComObject "Microsoft.Update.Session"
$objSearcher = $objSession.CreateUpdateSearcher()

If ($UpdateServer -eq "external"){
	$objSearcher.ServerSelection = 2
} else {
	$objSearcher.ServerSelection = 1
}

$objCollection = New-Object -ComObject "Microsoft.Update.UpdateColl"
$objResults = $objSearcher.Search("IsInstalled=0")

switch ($severity){
	"Critical" {$updates = $objResults.Updates | where {$_.MsrcSeverity -eq "Critical"}}
	"Important" {$updates = $objResults.Updates | where {("Important", "Critical") -contains $_.MsrcSeverity}}
	"Moderate" {$updates = $objResults.Updates | where {("Moderate", "Important", "Critical") -contains $_.MsrcSeverity}}
	"Low" {$updates = $objResults.Updates | where {("Low", "Moderate", "Important", "Critical") -contains $_.MsrcSeverity}}
	default {$updates = $objResults.Updates}
}

foreach($Update in $updates){
	$objCollectionTmp = New-Object -ComObject "Microsoft.Update.UpdateColl"
	        
	if (($Update.title -notmatch "Language") `
		-and ($Update.title -notlike "Windows Internet Explorer * for Windows *") `
		-and ($Update.title -notlike "Internet Explorer * for Windows *") `
		-and ($Update.title -notlike "Service Pack * for Windows *") `
		-and ($Update.title -notmatch "Genuine"))
	{
		if ( $Update.EulaAccepted -eq 0 ) { $Update.AcceptEula() }
    	$objCollectionTmp.Add($Update) | out-null
		$Downloader = $objSession.CreateUpdateDownloader() 
    	$Downloader.Updates = $objCollectionTmp
		$DownloadResult = $Downloader.Download()
	
		if($DownloadResult.ResultCode -eq 2)
    	{
            Write-Host $Update.Title " has been downloaded successfully."
			$objCollection.Add($Update) | out-null
    	}
	}
}

if($objCollection.count -eq 0){
	Write-Host "Windows is up-to-date!"
	& "reg" "add" "HKLM\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" "/v" "AutoAdminLogon" "/d" "0" "/t" "REG_SZ" "/F"
	& "reg" "delete" "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run" "/v" "WinUpdate" "/f"
	
	#Remove-Item "c:\temp\updateWindows.bat" -force -Confirm:$false
	
	$message = "Succeed to install Windows Updates in remote machine $hostName."
	if ($emailTo) { sendMail $emailTo $message }
	if ($uvsId) {notifyUvs $uvsId "1"}
	exit
}

foreach($Update in $objCollection){
	$objCollectionTmp = New-Object -ComObject "Microsoft.Update.UpdateColl"
	$objCollectionTmp.Add($Update) | out-null
	$objInstaller = $objSession.CreateUpdateInstaller()
	$objInstaller.Updates = $objCollectionTmp
	$InstallResult = $objInstaller.Install()
	
	if($InstallResult.ResultCode -eq 2){
		Write-Host $Update.Title " has been installed successfully."
	}
	
	#if($InstallResult.RebootRequired){
	#	Write-Host "Need to reboot the system to continue Windows update."
	#	& "shutdown" "/r" "/t" "0"
	#}
}

#Restart-Computer -Confirm:$false
& "shutdown" "/r" "/t" "0"