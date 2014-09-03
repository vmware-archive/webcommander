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

####	Push a pairing password into the connection server configuration
####  NOTE: we push it as plaintext, View itself would encypt it before putting
####        into LDAP but we'd need to plumb in the encryption code for that.
####        While this is low risk as only View administrators should have read
####        access to ADAM, please only use a one-off value.
####    - mpryor

function Set-PairingPassword() {
    param( [String] $password = 111111,
           [String] $csShortName = $(hostname), 
           [Int] $timeoutSecs = 86400)
    $serverou = [ADSI]"LDAP://localhost:389/ou=server,ou=properties,dc=vdi,dc=vmware,dc=int"
    $searcher = new-object System.DirectoryServices.DirectorySearcher($serverou)
    $searcher.filter= ("(cn=" + $csShortName + ")")
    $res = $searcher.findall()
    if ($res.count -ge 1) {
        $db = [ADSI] ($res[0].path)
        $db.put("pae-SecurityServerPairingPassword", $password)
        $db.put("pae-SecurityServerPairingPasswordTimeout", $timeoutSecs)
        $db.put("pae-SecurityServerPairingPasswordLastChangedTime", (get-date))
        $db.setinfo()
        return $db
    } else {
        throw ("ERROR: Server " + $csShortName + " not found")
    }
}
Set-PairingPassword