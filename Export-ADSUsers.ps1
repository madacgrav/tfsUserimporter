

[cmdletBinding()]
param (
    [string]$domainName,
    [string]$ADSPAT,
    [ValidateSet('2019','2020','2022')]
    [string]$ADSVersion,
    [string]$ADSCollecionUrl
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



$ADSGroupInfo = Get-TFSFullGroupsInfo -TFSversion $ADSVersion -TFSCollectionUrl $ADSCollecionUrl -olddomainname $domainName -PAT $ADSPAT

$ADSGroupInfo | ConvertTo-Json | Out-File -FilePath ".\Export_ADSGroupMemberships.json"