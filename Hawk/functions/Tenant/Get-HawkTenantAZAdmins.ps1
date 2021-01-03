Function Get-HawkTenantAZAdmins{
<#
.SYNOPSIS
    Tenant Azure Active Directory Administrator export. Must be connected to Azure-AD using the Connect-AzureAD cmdlet
.DESCRIPTION
    Tenant Azure Active Directory Administrator export. Reviewing administrator access is key to knowing who can make changes
    to the tenant and conduct other administrative actions to users and applications.
.EXAMPLE
    PS C:\>Get=HawkTenantAZAdmins
.OUTPUTS
    AzureADAdministrators.csv
.LINK
    https://docs.microsoft.com/en-us/powershell/module/azuread/get-azureaddirectoryrolemember?view=azureadps-2.0
.NOTES

#>
BEGIN{
    Out-LogFile "Gathering Azure AD Administrators"

    Test-AzureADConnection
    Send-AIEvent -Event "CmdRun"
}
PROCESS{
    $roles = foreach ($role in Get-AzureADDirectoryRole){
        $admins = (Get-AzureADDirectoryRoleMember -ObjectId $role.objectid).userprincipalname
            if ([string]::IsNullOrWhiteSpace($admins)) {
                [PSCustomObject]@{
                    AdminGroupName = $role.DisplayName
                    Members = "No Members"
                }
            }
        foreach ($admin in $admins){
            [PSCustomObject]@{
                AdminGroupName = $role.DisplayName
                Members = $admin
            }
        }
    }
    $roles | Out-MultipleFileType -FilePrefix "AzureADAdministrators" -csv

}
END{
    Out-LogFile "Completed exporting Azure AD Admins"
}
}#End Function