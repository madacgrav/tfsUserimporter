[cmdletBinding()]
param (
    [string]$domainName,
    [string]$PAT,
    [ValidateSet('2019','2020','2022')]
    [string]$ADSVersion,
    [string]$baseApiUrl
)


$username = ""
$Auth = '{0}:{1}' -f $username, $PAT
$Auth = [System.Text.Encoding]::UTF8.GetBytes($Auth)
$Auth = [System.Convert]::ToBase64String($Auth)
$header = @{Authorization = ("Basic {0}" -f $Auth) }

switch ($ADSVersion) {
    "2019" {
        $tfsecurity = "'C:\Program Files\Azure DevOps Server 2019\Tools\tfssecurity.exe'"
        $baseApiUrl = "$baseApiUrl/_apis/projects?api-version=5.0"
        break
    }
    "2020" {
        $tfsecurity = "'C:\Program Files\Azure DevOps Server 2020\Tools\tfssecurity.exe'"
        $baseApiUrl = "$baseApiUrl/_apis/projects?api-version=6.0"
        break
    }
    "2022" {
        $tfsecurity = "'C:\Program Files\Azure DevOps Server 2022\Tools\tfssecurity.exe'"
        $baseApiUrl = "$baseApiUrl/_apis/projects?api-version=7.0"
        break
    }
    default {
        $tfsecurity = "'C:\Program Files\Azure DevOps Server 2019\Tools\tfssecurity.exe'"
        $baseApiUrl = "$baseApiUrl/_apis/projects?api-version=5.0"
        break
    }
}
 
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
 
 
$allInfo = @()
 
$projects = (Invoke-RestMethod -Uri $baseApiUrl -Headers $header -Method GET  -ContentType application/json).value.Name
$info = Invoke-Expression "& $tfsecurity /g /collection:$baseApiUrl"
foreach ($line in $info) {
    if ($line -match 'Display name:\s*([^\n\r]*)') {
        $groupName = $matches[1]
        $members = Get-TFSGroupMembers -grouName $groupName -domain $domainname -collecionUrl $baseApiUrl -tfsecurityPath $tfsecurity
        $groupInfo = [psobject]@{
            Name = $groupName
            Members = $members
        }
        $allInfo +=  $groupInfo
        $groupInfo
    }
}
 
foreach ($project in $projects) {
    $info = Invoke-Expression "& $tfsecurity /g  $project /collection:$baseApiUrl"
    foreach ($line in $info) {
        if ($line -match 'Display name:\s*([^\n\r]*)') {
            $groupName = $matches[1]
            $members = Get-TFSGroupMembers -grouName $groupName -domain $domainname -collecionUrl $baseApiUrl -tfsecurityPath $tfsecurity
            $groupInfo = [psobject]@{
                Name = $groupName
                Members = $members
            }
            $groupInfo
        }
    }
}
 
$allInfo