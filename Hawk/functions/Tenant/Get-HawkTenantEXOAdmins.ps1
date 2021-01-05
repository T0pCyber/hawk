Function Get-HawkTenantEXOAdmins{
    <#
    .SYNOPSIS
        Exchange Online Administrator export. Must be connected to Exchange Online using the Connect-EXO cmdlet
    .DESCRIPTION
        After connecting to Exchange Online, this script will enumerate Exchange Online
        role group members and export the results to a .CSV file. Reviewing EXO admins can assist with determining
        who can change Exchange Online configurations and view
    .EXAMPLE
        PS C:\> Export-EXOAdmin -EngagementFolder foldername
        Exports Exchange Admins UserPrincipalName to .csv
    .OUTPUTS
        EXOAdmins.csv
    .NOTES
        nt
#>
BEGIN{
    Out-LogFile "Gathering Exchange Online Administrators"

    Test-EXOConnection
    Send-AIEvent -Event "CmdRun"
}
PROCESS{
    $roles = foreach ($Role in Get-RoleGroup){
        $ExchangeAdmins = Get-RoleGroupMember -Identity $Role.Identity | Select-Object -Property *
            foreach ($admin in $ExchangeAdmins){
                if([string]::IsNullOrWhiteSpace($admin.WindowsLiveId)){
                    [PSCustomObject]@{
                        ExchangeAdminGroup = $Role.Name
                        Members= $admin.name
                        RecipientType = $admin.RecipientType
                    }
                }
                else{
                    [PSCustomObject]@{
                        ExchangeAdminGroup = $Role.Name
                        Members = $admin.WindowsLiveId
                        RecipientType = $admin.RecipientType
                    }
                }
            }
        }
    $roles | Out-MultipleFileType -FilePrefix "ExchangeOnlineAdministrators" -csv

}
END{
    Out-Logfile "Completed exporting Exchange Online Admins"
}

}#End Function
