#
<#
.SYNOPSIS
  This script will import users from json export file from Azure DevOps Server to Azure DevOps Services.
.DESCRIPTION
  This script will import users from json export file from Azure DevOps Server to Azure DevOps Services.
.PARAMETER domainName
    The name of the Active Directory domain in the <domainName>\<username> format.
.PARAMETER ADOorgName
    The name of the Azure DevOps Services organization.
.PARAMETER ADOPAT
    The Personal Access Token for the Azure DevOps Services organization.
.PARAMETER jsonPathandFileName
    The path and file name of the json file exported from Azure DevOps Server.
.PARAMETER identityMapPath
    The path and file name of the csv file that maps the Active Directory users to their email addresses.
.INPUTS
  None
.OUTPUTS
  None
.NOTES
  Author:         Adam Graves
  Purpose/Change: Initial script development
  
.EXAMPLE
  Import-ADOUsers.ps1 -domainName "contoso" -ADOorgName "contoso" -ADOPAT "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx" -jsonPathandFileName "C:\Users\adamg\Documents\ADSExport.json" -identityMapPath "C:\Users\adamg\Documents\identityMap.csv"
#>
[cmdletBinding()]
param (
    [string]$domainName,
    [string]$ADOorgName,
    [string]$ADOpat,
    [string]$jsonPathandFileName,
    [string]$identityMapPath
)

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

#Set Error Action to Silently Continue
$ErrorActionPreference = "SilentlyContinue"

#----------------------------------------------------------[Declarations]----------------------------------------------------------

$identityMap = Import-Csv -Path $identityMapPath
$ADSGroupInfo = Get-Content -Path $jsonPathandFileName | ConvertFrom-Json
$ADOGroupInfo = Get-ADOGroupInfo -PAT $ADOpat -orgName $ADOorgName
$ADOUserInfo = Get-ADOUserInfo -PAT $ADOpat -orgName $ADOorgName

#-----------------------------------------------------------[Functions]------------------------------------------------------------


Function LogWrite([string]$logstring)
{
    $Logfile = ".\Logging\log.txt"
    $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    Add-content $Logfile -value "$Stamp - $logstring"
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
    $updateMemberAPI = "https://vssps.dev.azure.com/$orgName/_apis/graph/memberships/" + $userid + "/" + $groupID + "?api-version=7.1-preview.1"
    try {
        $respponse = Invoke-RestMethod -Uri $updateMemberAPI -Headers $header -Method PUT -ContentType application/json
        write-Debug $respponse
        return "success"
   }
   catch {
      write-host $_.Exception.Message
      return "failed"
   }
}

#-----------------------------------------------------------[Execution]------------------------------------------------------------

foreach ($ADSgroup in $ADSGroupInfo) {
    $groupFound = $false
    foreach ($ADO_group in $ADOGroupInfo) {
        $updatedName = $ADSgroup.Name.Replace("DefaultCollection", $ADOorgName)
        if ($updatedName -eq $ADO_group.Name) {
            $ADOgroupID = $ADO_group.id
            $groupFound = $true
        }
    }
    if ($groupFound) {
        $ADSgroup.Name
        foreach ($member in $ADSGroup.Members) {
            $identityFound = $false
            foreach ($identity in $identityMap) {
                $fullUser = $domainName + "\" + $member
                if ($fullUser -eq $identity.UserName) {
                    $emailAddress = $identity.Email
                    $identityFound = $true
                }
            }
            if ($identityFound) {
                $ADOuserFound = $false
                foreach ($ADO_user in $ADOUserInfo) {
                    if ($emailAddress -eq $ADO_user.Name) {
                        $ADOuserid = $ADO_user.id
                        $ADOuserFound = $true
                    }
                }
                if ($ADOuserFound) {
                    $status = Add-ADOUsertoGroup -userid $ADOuserid -groupID $ADOgroupID -PAT $ADOpat -orgName $ADOorgName
                    if ($status -eq "success") {
                        write-host ("User added to ADO: " + $member) -ForegroundColor Green
                    }
                    else {

                        write-host ("User not added to ADO: " + $member) -ForegroundColor Red
                    }
                }
                else {
                    write-host ("User not found in ADO: " + $member) -ForegroundColor Red
                }
            }
            else {
                write-host ("User not found in identityMap: " + $member) -ForegroundColor Yellow
            }
        }
    }
    else  {
        write-host ("Group not found in ADO: " + $ADSgroup.Name) -ForegroundColor DarkCyan
    }
}