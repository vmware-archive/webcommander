function newProp {
	Param($name, $value) 
	$prop = new-object PSObject -Property @{
    name = $name
    value = $value
  }
  return $prop
}

function newAdsiServer { 
	Param($address, $port, $user, $password, $dn, $filter)
  
  try {
    $root = New-Object DirectoryServices.DirectoryEntry("LDAP://$address`:$port/$dn", $user, $password)
    $root.gettype()
  } catch {
    addMsg "Fail - connect to ADSI server"
    addError
    endExec
  }
  
	if ($filter) {
    try {
      $searcher = new-object System.DirectoryServices.DirectorySearcher($root)
      $searcher.gettype()
      $searcher.filter = $filter
      $root = New-Object DirectoryServices.DirectoryEntry($searcher.findall()[0].path, $user, $password)
      $root.gettype()
    } catch {
      addToResult "Fail - connect to ADSI server with defined filter"
      endError
    }
	}

	$adsiServer = New-Object PSObject -Property @{
		root = $root
		user = $user
		password = $password
	}
	
	$adsiServer | add-member -MemberType ScriptMethod -value {
    param($name)
    try {
      $value = $this.root.get($name) 
      addToResult "Success - get ADSI property"
      $newProp = newProp $name $value
			addData $newProp
    } catch {
      addToResult "Fail - get ADSI property $name"
      endError
    }
	} -name getProperty
	
	$adsiServer | add-member -MemberType ScriptMethod -value {
    param($name)
    try {
      $this.root.putex(1, $name, 0)
      $this.root.setinfo()
      addMsg "Success - clear ADSI property $name"
    } catch {
      addToResult "Fail - clear ADSI property $name"
      endError
    }
	} -name clearProperty
	
	$adsiServer | add-member -MemberType ScriptMethod -value {
    param($name, $value)
    try {
      $valueList = @($value.split(',').trim())
      $this.root.putex(2, $name, $valueList)
      $this.root.setinfo()
      addToResult "Success - update ADSI property $name to $value"
    } catch {
      addToResult "Fail - update ADSI property $name to $value"
      endError
    }	
	} -name updateProperty
	
	$adsiServer | add-member -MemberType ScriptMethod -value {
    param($name, $value)
    try {
			$valueList = @($value.split(',').trim())
      $this.root.putex(3, $name, $valueList)
      $this.root.setinfo()	
      addToResult "Success - append $value to ADSI property $name"
    } catch {
      addToResult "Fail - append $value to ADSI property $name"
      endError
    }		
	} -name appendProperty
	
	$adsiServer | add-member -MemberType ScriptMethod -value {
    param($name)
    try {
			$this.root.putex(4, $name, 0)
      $this.root.setinfo()
      addToResult "Success - delete ADSI property $name"
    } catch {
      addToResult "Fail - delete ADSI property $name"
      endError
    }	
	} -name deleteProperty
	
	return $adsiServer
}