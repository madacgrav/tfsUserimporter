[cmdletBinding()]
param (
    [string]$domainName,
    [string]$ADSPAT,
    [ValidateSet('2019','2020','2022')]
    [string]$ADSVersion,
    [string]$ADSCollecionUrl,
    [string]$ADOorgName,
    [string]$ADOpat
)

 
function Get-TFSGroupMembers ([string]$grouName, [string]$domain, [string]$collecionUrl, [string]$tfsecurityPath) {
    $rawMembers = Invoke-Expression "& $tfsecurityPath /imx '$grouName' /collection:$collecionUrl"
    $members = @()
    foreach ($line in $rawMembers) {
       $matchstring = $domain + '\\s*([^\n\r\s]*\S)'
        if ($line -match $matchstring) {
            $members += $matches[1]
        }
    }
    return $members
}
 

function Get-TFSFullGroupsInfo ([string]$TFSversion, [string]$TFSCollectionUrl, [string]$olddomainname, [string]$PAT) {

    switch ($TFSversion) {
        "2019" {
            $tfsecurity = "'C:\Program Files\Azure DevOps Server 2019\Tools\tfssecurity.exe'"
            $ADSbaseApiUrl = "$TFSCollectionUrl/_apis/projects?api-version=5.0"
            break
        }
        "2020" {
            $tfsecurity = "'C:\Program Files\Azure DevOps Server 2020\Tools\tfssecurity.exe'"
            $ADSbaseApiUrl = "$TFSCollectionUrl/_apis/projects?api-version=6.0"
            break
        }
        "2022" {
            $tfsecurity = "'C:\Program Files\Azure DevOps Server 2022\Tools\tfssecurity.exe'"
            $ADSbaseApiUrl = "$TFSCollectionUrl/_apis/projects?api-version=7.0"
            break
        }
        default {
            $tfsecurity = "'C:\Program Files\Azure DevOps Server 2019\Tools\tfssecurity.exe'"
            $ADSbaseApiUrl = "$TFSCollectionUrl/_apis/projects?api-version=5.0"
            break
        }
    }

    $allInfo = @()
    $info = Invoke-Expression "& $tfsecurity /g /collection:$TFSCollectionUrl"
    foreach ($line in $info) {
        if ($line -match 'Display name:\s*([^\n\r]*)') {
            $groupName = $matches[1]
            $members = Get-TFSGroupMembers -grouName $groupName -domain $olddomainname -collecionUrl $TFSCollectionUrl -tfsecurityPath $tfsecurity
            $groupInfo = [psobject]@{
                Name = $groupName
                Members = $members
            }
            $allInfo +=  $groupInfo
        }
    }
    
    $username = ""
    $Auth = '{0}:{1}' -f $username, $PAT
    $Auth = [System.Text.Encoding]::UTF8.GetBytes($Auth)
    $Auth = [System.Convert]::ToBase64String($Auth)
    $header = @{Authorization = ("Basic {0}" -f $Auth) }
    $projects = (Invoke-RestMethod -Uri $ADSbaseApiUrl -Headers $header -Method GET  -ContentType application/json).value.Name
    foreach ($project in $projects) {
        $info = Invoke-Expression "& $tfsecurity /g  $project /collection:$TFSCollectionUrl"
        foreach ($line in $info) {
            if ($line -match 'Display name:\s*([^\n\r]*)') {
                $groupName = $matches[1]
                $members = Get-TFSGroupMembers -grouName $groupName -domain $olddomainname -collecionUrl $TFSCollectionUrl -tfsecurityPath $tfsecurity
                $groupInfo = [psobject]@{
                    Name = $groupName
                    Members = $members
                }
                $allInfo +=  $groupInfo
            }
        }
    }
     
    return $allInfo
}

function Get-ADOGroupInfo ([string]$PAT, [string]$orgName) {
    $username = ""
    $Auth = '{0}:{1}' -f $username, $PAT
    $Auth = [System.Text.Encoding]::UTF8.GetBytes($Auth)
    $Auth = [System.Convert]::ToBase64String($Auth)
    $header = @{Authorization = ("Basic {0}" -f $Auth) }

    $groupApiUrl = "https://vssps.dev.azure.com/$orgName/_apis/graph/groups?api-version=7.1-preview.1"
    $groups = (Invoke-RestMethod -Uri $groupApiUrl -Headers $header -Method GET  -ContentType application/json).value

    $adoGroups = @()

    foreach ($group in $groups) {
        if ($group.origin -eq "vsts") {
            $groupInfo = [psobject]@{
                Name = $group.principalName
                id = $group.descriptor
            }
            $adoGroups += $groupInfo
        }
    }
    return $adoGroups
}


function Get-ADOUserInfo ([string]$PAT, [string]$orgName) {
    $username = ""
    $Auth = '{0}:{1}' -f $username, $PAT
    $Auth = [System.Text.Encoding]::UTF8.GetBytes($Auth)
    $Auth = [System.Convert]::ToBase64String($Auth)
    $header = @{Authorization = ("Basic {0}" -f $Auth) }
    $userApiurl = "https://vssps.dev.azure.com/$orgName/_apis/graph/users?api-version=7.1-preview.1"

    $users = (Invoke-RestMethod -Uri $userApiurl -Headers $header -Method GET  -ContentType application/json).value
    $adoUsers = @()

    foreach ($user in $users) {
        $userInfo = [psobject]@{
            Name = $user.principalName
            id = $user.descriptor
        }
        $adoUsers += $userInfo
    }
    return $adoUsers
}

function Add-ADOUsertoGroup ([string]$userid, [string]$groupID,[string]$PAT, [string]$orgName) {
    $username = ""
    $Auth = '{0}:{1}' -f $username, $PAT
    $Auth = [System.Text.Encoding]::UTF8.GetBytes($Auth)
    $Auth = [System.Convert]::ToBase64String($Auth)
    $header = @{Authorization = ("Basic {0}" -f $Auth) }
    $updateMemberAPI = "https://vssps.dev.azure.com/$orgName/_apis/graph/memberships/" + $uuserid + "/" + $groupID + "?api-version=7.1-preview.1"
    try {
        $resposne = Invoke-RestMethod -Uri $updateMemberAPI -Headers $header -Method PUT  -ContentType application/json
        return "success"
    }
    catch {
        return "failed"
    }
    
}


$identityMap = Import-Csv -Path ".\identityMap.csv" | ConvertFrom-Csv -Delimiter ';'
$ADSGroupInfo = Get-TFSFullGroupsInfo -TFSversion $ADSVersion -TFSCollectionUrl $ADSCollecionUrl -olddomainname $domainName -PAT $ADSPAT
$ADOGroupInfo = Get-ADOGroupInfo -PAT $ADOpat -orgName $ADOorgName
$ADOUserInfo = Get-ADOUserInfo -PAT $ADOpat -orgName $ADOorgName


foreach ($ADSgroup in $ADSGroupInfo) {
    $group.Name
    $groupFound = $false
    foreach ($ADO_group in $ADOGroupInfo) {
        if ($ADSgroup.Name -eq $ADO_group.Name) {
            $ADOgroupID = $ADO_group.id
            $groupFound = $true
        }
    }
    if ($groupFound) {
        foreach ($member in $ADSGroup.Members) {
            foreach ($identity in $identityMap) {
                $identityFound = $false
                $fullUser = $domainName + "\" + $member
                if ($fullUser -eq $identity.UserName) {
                    $emailAddress = $identity.Email
                    $identityFound = $true
                }
            }
            if ($identityFound) {
                foreach ($ADO_user in $ADOUserInfo) {
                    $ADOuserFound = $false
                    if ($emailAddress -eq $ADO_user.principalName) {
                        $ADOuserid = $ADO_user.id
                        $ADOuserFound = $true
                    }
                }
                if ($ADOuserFound) {
                    $status = Add-ADOUsertoGroup -userid $ADOuserid -groupID $ADOgroupID -PAT $ADOpat -orgName $ADOorgName
                    if ($status -eq "success") {
                        write-host ("User added to ADO: " + $member)
                    }
                    else {
                        write-host ("User not added to ADO: " + $member)
                    }
                }
                else {
                    write-host ("User not found in ADO: " + $member)
                }
            }
            else {
                write-host ("User not found in identityMap: " + $member)
            }
        }
    }
    else  {
        write-host ("Group not found in ADO: " + $ADSgroup.Name)
    }
}
