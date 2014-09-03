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

Param (
	$userPrefix,
	$totalUser,
	$userPassword,
	$groupPrefix,
	$totalGroup
)

$userPerGroup = [math]::floor($totalUser / $totalGroup)

$p = ConvertTo-SecureString $userPassword -asPlainText -Force

import-module activedirectory -ea silentlycontinue

get-aduser -filter "name -like '$userPrefix*'" | remove-aduser -confirm:$false
get-adgroup -filter "name -like '$groupPrefix*'" | remove-adgroup -confirm:$false

(1..$totalUser) | % {
	new-aduser -name "$userPrefix$_" -accountPassword $p -cannotChangePassword:$true -enabled:$true
} 
(1..$totalGroup) | % {
	new-adGroup -name "$groupPrefix$_" -groupscope global
} 
(1..$totalGroup) | %{
	$user = @()
	for ($i=1; $i -le $userPerGroup; $i++){
		$number = ($_ - 1) * $userPerGroup + $i
		$user += "$userPrefix$number"
	}  
	add-adgroupmember "$groupPrefix$_" $user
}