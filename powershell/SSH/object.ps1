function newSshServer {
	Param($address, $user, $password)
	try {
		import-module posh-ssh -ea stop
	} catch {
		addToResult "Fail - import POSH-SSH module"
		addToResult "Info - need to install POSH-SSH on webcommander server https://github.com/darkoperator/Posh-SSH"
		endExec
	}
	$cred = new-object -typeName System.management.automation.pscredential -argumentList $user, (ConvertTo-SecureString $password -asPlainText -Force)
	try {
		get-sshtrustedhost | remove-sshtrustedhost
		$sshSession = new-sshsession -computername $address -credential $cred -AcceptKey $true
		$sftpSession = new-sftpsession -computername $address -credential $cred -AcceptKey $true
	} catch {
		addToResult "Fail - connect to SSH server $address"
		endError
	}

	$sshServer = New-Object PSObject -Property @{
		address = $address
		user = $user
		password = $password
		sshSession = $sshSession
		sftpSession = $sftpSession
	}
	
	$sshServer | add-member -MemberType ScriptMethod -value {
    param($cmd, $outputCheck, $pattern)
		$cmd = $cmd -replace "`r`n","`n"
		try {
			$result = invoke-sshcommand -command $cmd -sshSession $this.sshSession
		} catch {
			addToResult "Fail - run SSH script"
      endError
		}
		if ($result.exitStatus -eq 0) {
			addToResult "Success - run SSH script"
			if ($pattern) {
				try {
					$verification = invoke-expression "'$($result.output)' -$outputCheck '$pattern'"
					if ($verification) {
						addToResult "Success - verify SSH script output"
					} else {
						addToResult "Fail - verify SSH script output"
					}
				} catch {
					addToResult "Fail - syntax error to verify SSH script"
					endError
				}
			}
		} else {
			addToResult "Fail - run SSH script"
			addToResult $result.error "raw"
		}
		if ($result.output) {addToResult $result.output "raw"}
	} -name runCommand
	
	$sshServer | add-member -MemberType ScriptMethod -value {
    param($localFile, $remotePath)
		$fileName = ($localFile.split("\"))[-1]
		try {
			set-sftpfile -sftpsession $this.sftpsession -localfile $localFile -remotePath $remotePath -ea stop
			addToResult "Success - copy file $fileName to $($this.address)"
		} catch {
			addToResult "Fail - copy file $fileName to $($this.address)"
			endError
		}
	} -name copyFileSftp
	
	$sshServer | add-member -MemberType ScriptMethod -value {
    param($localFile, $remoteFile)
		try {
			"y" | set-scpfile -computername $this.address -credential $cred -localfile $localFile -remotePath $remoteFile
		} catch {
			addToResult "Fail - copy file via SCP"
			endError
		}
		addToResult "Success - copy file via SCP"
	} -name copyFileScp
	
	return $sshServer
}