﻿Function Get-HawkTenantAzureADUsers{
<#
.SYNOPSIS
    This function will export all the Azure Active Directory users.
.DESCRIPTION
    This function will export all the Azure Active Directory users to .csv file. This data can be used
    as a reference for user presence and details about the user for additional context at a later time. This is a point
    in time users enumeration. Date created can be of help when determining account creation date.
.EXAMPLE
    PS C:\>Get-HawkTenantAzureADUsers
    Exports all Azure AD users to .csv
.OUTPUTS
    AzureADUPNS.csv
.LINK
    https://docs.microsoft.com/en-us/powershell/module/azuread/get-azureaduser?view=azureadps-2.0
.NOTES
#>
BEGIN{
    #Initializing Hawk Object if not present
    if ([string]::IsNullOrEmpty($Hawk.FilePath)) {
		Initialize-HawkGlobalObject
	}
    Out-LogFile "Gathering Azure AD Users"

    Test-AzureADConnection
    Send-AIEvent -Event "CmdRun"

}#End BEGIN
PROCESS{
    $users = foreach ($user in (Get-AzureADUser -All $True)){
        $userproperties = $user | Select-Object userprincipalname, objectid, usertype, userstatechangedon, DirSyncEnabled, ExtensionProperty
            foreach ($properties in $userproperties){
                [PSCustomObject]@{
                UserPrincipalname = $userproperties.userprincipalname
                ObjectID = $userproperties.objectid
                UserType = $userproperties.UserType
                DateCreated = $userproperties.ExtensionProperty.createdDateTime
                UserStateChangedOn = $userproperties.UserStateChangedOn
                DirSyncEnabled = $userproperties.DirSyncEnabled
                }
            }
    }
    $users | Sort-Object -property UserPrincipalname | Out-MultipleFileType -FilePrefix "AzureADUsers" -csv -json
}#End PROCESS
END{
    Out-Logfile "Completed exporting Azure AD users"
}#End END


}#End Function