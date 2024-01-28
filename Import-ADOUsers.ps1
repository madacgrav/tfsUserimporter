[cmdletBinding()]
param (
    [string]$domainName,
    [string]$ADOorgName,
    [string]$ADOpat
)


$identityMap = Import-Csv -Path ".\identityMap.csv" | ConvertFrom-Csv -Delimiter ';'
$ADSGroupInfo = Get-Content -Path ".\Export_ADSGroupMemberships.json" | ConvertFrom-Json
$ADOGroupInfo = Get-ADOGroupInfo -PAT $ADOpat -orgName $ADOorgName
$ADOUserInfo = Get-ADOUserInfo -PAT $ADOpat -orgName $ADOorgName


foreach ($ADSgroup in $ADSGroupInfo) {
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