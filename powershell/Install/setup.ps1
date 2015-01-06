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

<#
	.SYNOPSIS
		Install WebCommander 

	.DESCRIPTION
		This command installs and configures WebCommander.
		This command should not show on the index page.
		
	.FUNCTIONALITY
		noshow
		
	.NOTES
		AUTHOR: Jerry Liu
		EMAIL: liuj@vmware.com
#>

Param (
	$packageUrl = 'https://github.com/vmware/webcommander/archive/master.zip',
	$authentication = 'Windows',
	$adminPassword = 'Passw0rd', # administrator password of the windows machine where webcommander is located
	$defaultPassword = 'Passw0rd' # default password used to communicate with vSphere, VM and remote machine
)

$packageName = ($packageUrl.split("/"))[-1]

$errorActionPreference = "Stop"

if (test-path "$env:windir\syswow64\") {
	& "$env:windir\syswow64\windowspowershell\v1.0\powershell.exe" `
		-command "set-executionpolicy RemoteSigned -force"
}
if (!(test-path C:\WebCommander -pathType container)) {
	mkdir C:\WebCommander -force -ea SilentlyContinue | out-null
}

$download = {
	param (
		$webCommanderOnly = $false
	)
	$webClient = new-object system.net.webclient
	if (!$webCommanderOnly) {
		write-output "Downloading PowerCLI, WPI and Advanced Logging..."
		if (test-connection buildweb.eng.vmware.com -quiet) {
			$webClient.downloadfile('http://build-squid.eng.vmware.com/build/mts/release/bora-1997510/publish/VMware-PowerCLI-5.8.0-1997510.exe',
				'C:\WebCommander\PowerCLI.exe')
		}
		$webClient.downloadfile('http://go.microsoft.com/fwlink/?LinkId=255386',
			'C:\WebCommander\wpilauncher.exe')
		$webClient.downloadfile('http://download.microsoft.com/download/9/6/5/96594C39-9918-466C-AFE0-920737351987/AdvancedLogging64.msi',
			'C:\WebCommander\AdvancedLogging64.msi')
		write-output "`t PowerCLI, WPI and Advanced Logging downloaded successfully."
	}
	write-output "Downloading WebCommander package..."
	$webClient.downloadfile($packageUrl, "C:\WebCommander\$packageName")
	write-output "`t WebCommander package downloaded successfully"
}

$installIis = {
	$test = get-command get-website -ea SilentlyContinue
	if (!$test) {
		write-output "Installing IIS..."
		if (get-command install-windowsfeature -ea silentlycontinue) {
			$installcmd = 'Install-WindowsFeature -name Web-Server -IncludeManagementTools -IncludeAllSubFeature -confirm:$false -wa 0 | out-null'
		} elseif (get-command add-windowsfeature -ea silentlycontinue) {
			$installcmd = 'add-WindowsFeature -name Web-Server -IncludeAllSubFeature -confirm:$false -wa 0 | out-null'
		} elseif (get-command ServerManagerCmd -ea silentlycontinue) {
			$installcmd = 'start-process "c:\windows\system32\ServerManagerCmd.exe" -argumentlist " -install web-server -a" -wait'
		} else {
            $installcmd = 'start-process "c:\windows\system32\PkgMgr.exe" -argumentlist " /iu:IIS-WebServerRole;IIS-Security;IIS-WindowsAuthentication" -wait'
		}
		try {
			invoke-expression $installcmd
		} catch {
			write-warning "`t Failed to install IIS."
			write-warning "`t Please install it and all sub components manually, and run this script again."
			exit
		}
		write-output "`t IIS installed successfully."	
	} else {
		write-output "IIS is already installed."
	}	
}

$installWpi = {
	if (!(test-path "C:\Program Files\Microsoft\Web Platform Installer\webpicmd.exe")) {
		write-output "Installing Web Platform Installer..."
		C:\WebCommander\wpilauncher.exe 
		do {
			start-sleep 5
		} while (!(get-process -name webplatforminstaller -ea silentlycontinue))
		get-process -name webplatforminstaller | kill
		if (!(test-path "C:\Program Files\Microsoft\Web Platform Installer\webpicmd.exe")) {
			write-warning "`t Failed to install Web Platform Installer."
			write-warning "`t Please install it manually, and run this script again."
			exit
		}
		write-output "`t Web Platform Installer installed successfully."
	} else {
		write-output "Web Platform Installer is already installed."
	}
}

$installPhp = {
	if (!(test-path "C:\Program Files (x86)\PHP\v5.3\php.exe")) {
		write-output "Installing PHP..."
		'Y' | C:\Program` Files\Microsoft\Web` Platform` Installer\webpicmd.exe /install /products:PHP53 | out-null
		if (!(test-path "C:\Program Files (x86)\PHP\v5.3\php.exe")) {
			write-warning "`t Failed to install PHP."
			write-warning "`t Please install it manually, and run this script again."
			exit
		}
		write-output "`t PHP installed successfully."
	} else {
		write-output "PHP is already installed."
	}
}

$installPowerCli = {
	$test = get-pssnapin -name vmware.vimautomation.core -ea silentlyContinue
	if (!$test) {
		$cmd = "C:\WebCommander\PowerCLI.exe"
		if (test-path $cmd) {
			write-output "Installing PowerCLI..."
			$cmdPara = " /s /v/qn"
			$installprocess = [System.Diagnostics.Process]::Start($cmd, $cmdPara)
			$installprocess.WaitForExit()
			If ((0,3010) -notcontains $installprocess.ExitCode) {  
				write-warning "`t Failed to install PowerCLI."
				write-warning "`t Please install it manually, and run this script again."
				exit
			}
			write-output "`t PowerCLI installed successfully."
		} else {
			write-warning "PowerCLI installer is not available."
			write-warning "Please download and install PowerCLI manually."
		}
	} else {
		write-output "PowerCLI is already installed."
	}	
}

$extractWebCommander = {
	write-output "Extracting WebCommander package..."
	$shell = new-object -com shell.application
	$zip = $shell.namespace("C:\WebCommander\$packageName") 
	$destination = $shell.namespace('c:\WebCommander')
	$destination.Copyhere($zip.items(),20)
	$folder = "c:\webcommander\webcommander-master"
	if (test-path $folder) {
		copy $folder\* c:\webcommander\ -recurse -force -confirm:$false
		rm $folder -recurse -force -confirm:$false
	}
	write-output "`t WebCommander package extracted successfully."
}

$addWebCommanderSite = {
    import-module webadministration 
	try {
		get-website | stop-website
	} catch {
		write-warning "Fail to stop existing web sites. "
		write-warning "`t Please stop existing web sites manually, and run this script again."
		exit
	}
	write-output "Stopped all existing websites."
	write-output "Creating WebCommander website..."
	$physicalPath = "C:\WebCommander\www"
	try {
		new-website -name WebCommander -port 80 -PhysicalPath $physicalPath -force | start-website
	} catch {
		write-warning "`t Fail to create and start web site."
		write-warning "`t Please make sure IIS Management Service is started."
		exit
	}
	set-webconfigurationproperty /system.webServer/defaultDocument -name files -value @{value="webcmd.php"} -location WebCommander
	write-output "`t WebCommander website created successfully."
}

$configAuthentication = {
	param (
		$type = "anonymous"
	)
	write-output "Configuring website authentication..."
	if ($type -eq "anonymous") {
		Set-WebConfigurationProperty `
			"system.applicationHost/sites/site[@name='WebCommander']/application[@path='/']/virtualDirectory[@path='/']" `
			-name username -value Administrator
		Set-WebConfigurationProperty `
			"system.applicationHost/sites/site[@name='WebCommander']/application[@path='/']/virtualDirectory[@path='/']" `
			-name password -value $adminPassword
		write-output "`t Anonymous authentication is enabled."
		write-output "`t WebCommander website runs as local administrator."
	} else {
		Set-WebConfigurationProperty -filter /system.WebServer/security/authentication/AnonymousAuthentication `
			-name enabled -value false -location WebCommander
		Set-WebConfigurationProperty -filter /system.WebServer/security/authentication/windowsAuthentication `
			-name enabled -value true -location WebCommander
		write-output "`t Windows authentication is enabled."
	}
}

$installAdvancedLogging = {
	$test = Get-WmiObject -Class Win32_Product | ? {$_.name -match "IIS Advanced Logging"}
	if (!$test) {
		write-output "Installing IIS Advanced Logging..."
		#msiexec /i C:\WebCommander\AdvancedLogging64.msi /passive
		$test = (Start-Process -FilePath "msiexec.exe" -ArgumentList `
			"/i C:\WebCommander\AdvancedLogging64.msi /passive" -Wait -Passthru).ExitCode
		#$test = Get-WmiObject -Class Win32_Product | ? {$_.name -match "IIS Advanced Logging"}
		if ($test -ne 0) {
			write-warning "`t Failed to install IIS Advanced Logging."
			write-warning "`t Please install it manually, and run this script again."
			exit
		}
		write-output "`t IIS Advanced Logging installed successfully."
	} else {
		write-output "IIS Advanced Logging is already installed."
	}
}

$configAdvancedLogging = {
	write-output "Configuring IIS Advanced Logging..."
	$filter = "system.webServer/advancedLogging/server"
	Set-WebConfigurationProperty -Filter system.webServer/httpLogging `
		-PSPath machine/webroot/apphost -Name dontlog -Value true | out-null
		
	$definition = @(
		@{id="url";sourceName="url";sourceType="ResponseHeader"},
		@{id="user";sourceName="user";sourceType="ResponseHeader"},
		@{id="return-code";sourceName="return-code";sourceType="ResponseHeader"}
	)
	$definition | Add-WebConfiguration "$filter/fields" | out-null
	
	Set-WebConfigurationProperty `
		-Filter "$filter/logDefinitions/logDefinition[@baseFileName='%COMPUTERNAME%-Server']" `
		-name enabled -value false | out-null
	Add-WebConfiguration "$filter/logDefinitions" -location WebCommander -value `
		@{baseFileName="WebCommander";enabled="true";logRollOption="Schedule";schedule="Weekly";publishLogEvent="false"}
	
	$filter += "/logDefinitions/logDefinition[@baseFileName='WebCommander']/selectedFields"
	$definition = @(
		@{defaultValue="";required="false";logHeaderName="date";id="Date-UTC"},
		@{defaultValue="";required="false";logHeaderName="time";id="Time-UTC"},
		@{defaultValue="";required="false";logHeaderName="";id="user"},
		@{defaultValue="";required="false";logHeaderName="c-ip";id="Client-IP"},
		@{defaultValue="";required="false";logHeaderName="cs(User-Agent)";id="User Agent"},
		@{defaultValue="";required="false";logHeaderName="cs-method";id="Method"},
		@{defaultValue="";required="false";logHeaderName="";id="url"},
		@{defaultValue="";required="false";logHeaderName="";id="return-code"},
		@{defaultValue="";required="false";logHeaderName="TimeTakenMS";id="Time Taken"}
	)
	$definition | Add-WebConfiguration "$filter" -Location WebCommander | out-null
	write-output "`t IIS Advanced Logging configured successfully."
}

$editProfile = {
	write-output "Changing x86 Powershell profile..."
	$p = @"
[Reflection.Assembly]::LoadWithPartialName('system.web') | out-null
add-pssnapin vmware* -ea SilentlyContinue
`$env:defaultPassword = '$defaultPassword'
"@
	$p | set-content C:\windows\SysWOW64\WindowsPowerShell\v1.0\Profile.ps1
	write-output "`t x86 Powershell profile changed successfully."
}

$configWsman = {
	write-output "Changing WSMAN settings..."
	cd wsman:
	cd \localhost\client
	set-item Trustedhosts * -force
	write-output "`t WSMAN settings changed successfully."
	#restart-service winrm
}

try {
	import-module webadministration
	$website = get-website | ?{$_.name -eq "WebCommander"}
} catch {}
if ($website) {
	write-output "WebCommander website already exists."
	write-output "`t Updating it with $packageUrl..."
	& $download -webCommanderOnly $true 
	$website | stop-website
	& $extractWebCommander
	$website | start-website
	write-output "`t WebCommander website updated successfully."
} else {
	& $download
	& $installIis
	& $installWpi
	& $installPowerCli
	& $installPhp
	& $extractWebCommander
	import-module webadministration
	& $addWebCommanderSite
	& $configAuthentication $authentication
	& $installAdvancedLogging
	& $configAdvancedLogging
	& $editProfile
	& $configWsman
}