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

Param ($updateServer="external",$severity="all")

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
		-and ($Update.title -notlike "* Windows Defender *") `
		-and ($Update.title -notmatch "Genuine"))
	{
		if ( $Update.EulaAccepted -eq 0 ) { $Update.AcceptEula() }
    	$objCollectionTmp.Add($Update) | out-null
		$Downloader = $objSession.CreateUpdateDownloader() 
    	$Downloader.Updates = $objCollectionTmp
		$DownloadResult = $Downloader.Download()
	
		if($DownloadResult.ResultCode -eq 2)
    	{
            Write-output $Update.Title " has been downloaded successfully."
			$objCollection.Add($Update) | out-null
    	}
	}
}

if($objCollection.count -eq 0){
	write-output "no more update to install"
	exit
}

foreach($Update in $objCollection){
	$objCollectionTmp = New-Object -ComObject "Microsoft.Update.UpdateColl"
	$objCollectionTmp.Add($Update) | out-null
	$objInstaller = $objSession.CreateUpdateInstaller()
	$objInstaller.Updates = $objCollectionTmp
	$InstallResult = $objInstaller.Install()
	if($InstallResult.ResultCode -eq 2){
		Write-output $Update.Title " has been installed successfully."
	} else {
		Write-output ($Update.Title + " install failed, exit code: " + $InstallResult.ResultCode)
	}
	
	# if($InstallResult.RebootRequired){
		# write-output "need to reboot machine to continue"
		# exit
	# }
}

$objSystemInfo = New-Object -ComObject "Microsoft.Update.SystemInfo"	
If($objSystemInfo.RebootRequired){
	write-output "need to reboot machine to continue"
} else {
	write-output "no more update to install"
}