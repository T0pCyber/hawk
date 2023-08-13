Function Get-HawkTenantAZAdmins{
<#
.SYNOPSIS
    Tenant Azure Active Directory Administrator export. Must be connected to Azure-AD using the Connect-AzureAD cmdlet
.DESCRIPTION
    Tenant Azure Active Directory Administrator export. Reviewing administrator access is key to knowing who can make changes
    to the tenant and conduct other administrative actions to users and applications.
.EXAMPLE
    Get-HawkTenantAZAdmins
    Gets all Azure AD Admins
.OUTPUTS
    AzureADAdministrators.csv
.LINK
    https://docs.microsoft.com/en-us/powershell/module/azuread/get-azureaddirectoryrolemember?view=azureadps-2.0
.NOTES
#>
BEGIN{
    #Initializing Hawk Object if not present
    if ([string]::IsNullOrEmpty($Hawk.FilePath)) {
        Initialize-HawkGlobalObject
    }
    Out-LogFile "Gathering Azure AD Administrators"

    Test-AzureADConnection
    Send-AIEvent -Event "CmdRun"
}
PROCESS{
    $roles = foreach ($role in Get-MgDirectoryRole){
        $admins = (Get-MGDirectoryRoleMember -DirectoryRoleId $role.id)
            if ([string]::IsNullOrWhiteSpace($admins)) {
                [PSCustomObject]@{
                    AdminGroupName = $role.DisplayName
                    Members = "No Members"
                }
            }
        foreach ($admin in $admins){
            if($admin.AdditionalProperties.'@odata.type' -eq "#microsoft.graph.user"){
                [PSCustomObject]@{
                    AdminGroupName = $role.DisplayName
                    Members = $admin.AdditionalProperties.userPrincipalName
                }
            }
            else{
                [PSCustomObject]@{
                    AdminGroupName = $role.DisplayName
                    Members = $admin.AdditionalProperties.displayName
                }
            }
        }
    }
    $roles | Out-MultipleFileType -FilePrefix "AzureADAdministrators" -csv -json

}
END{
    Out-LogFile "Completed exporting Azure AD Admins"
}
}#End Function