Function Get-HawkUserAdminAudit {
    <#
    .SYNOPSIS
        Searches the Unified Audit logs for any commands that were run against the provided user object.
    .DESCRIPTION
        Searches the Unified Audit logs for any commands that were run against the provided user object.
        Limited by the provided search period.
    .PARAMETER UserPrincipalName
        UserPrincipalName of the user you're investigating
    .OUTPUTS
        File: Simple_User_Changes.csv
        Path: \<user>
        Description: All cmdlets that were run against the user in a simple format.

        File: User_Changes.csv
        Path: \<user>
        Description: Raw data of all changes made to the user.

        File: User_Changes_Raw.json
        Path: \<user>
        Description: Raw JSON data from audit logs.

        File: User_Changes_Raw.txt
        Path: \<user>
        Description: Human readable format of raw audit data.
    .EXAMPLE
        Get-HawkUserAdminAudit -UserPrincipalName user@company.com

        Gets all changes made to user@company.com and outputs them to the csv and json files.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [array]$UserPrincipalName
    )

    Test-EXOConnection
    Send-AIEvent -Event "CmdRun"

    # Verify our UPN input
    [array]$UserArray = Test-UserObject -ToTest $UserPrincipalName

    foreach ($Object in $UserArray) {
        [string]$User = $Object.UserPrincipalName

        # Get the mailbox name since that is what we store in the admin audit log
        $MailboxName = (Get-Mailbox -Identity $User).Name

        Out-LogFile ("Searching for changes made to: " + $MailboxName) -action

        # Get all changes for this user
        [array]$UserChanges = Search-UnifiedAuditLog -UserIds $User -StartDate $Hawk.StartDate -EndDate $Hawk.EndDate -RecordType ExchangeAdmin -Operations "*" -ResultSize 5000

        # If there are any results push them to an output file
        if ($UserChanges.Count -gt 0) {
            Out-LogFile ("Found " + $UserChanges.Count + " changes made to this user")

            # Get the user's output folder path
            $UserFolder = Get-HawkUserPath -User $User

            # Write raw AuditData to files for verification/debugging
            $RawJsonPath = Join-Path -Path $UserFolder -ChildPath "User_Changes_Raw.json"
            $UserChanges | Select-Object -ExpandProperty AuditData | Out-File -FilePath $RawJsonPath

            $RawTxtPath = Join-Path -Path $UserFolder -ChildPath "User_Changes_Raw.txt"
            "User: $User" | Out-File -FilePath $RawTxtPath
            $UserChanges | Select-Object -ExpandProperty AuditData | Out-File -FilePath $RawTxtPath -Append
            "------------------------------------" | Out-File -FilePath $RawTxtPath -Append

            # Parse and format the changes using Get-SimpleUnifiedAuditLog
            $ParsedChanges = $UserChanges | Get-SimpleUnifiedAuditLog

            # Output the processed results
            if ($ParsedChanges) {
                $ParsedChanges | Out-MultipleFileType -FilePrefix "Simple_User_Changes" -csv -json -User $User
            }

            # Output the raw changes
            $UserChanges | Out-MultipleFileType -FilePrefix "User_Changes" -csv -json -User $User
        }
        else {
            Out-LogFile "No User Changes found."
        }
    }
}