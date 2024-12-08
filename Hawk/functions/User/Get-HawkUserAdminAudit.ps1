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
        Path: <user>
        Description: All cmdlets that were run against the user in a simple format.
    .EXAMPLE
        Get-HawkUserAdminAudit -UserPrincipalName user@company.com

        Gets all changes made to user@company.com and outputs them to the csv and json files.
    #>

        param
        (
            [Parameter(Mandatory = $true)]
            [array]$UserPrincipalName
        )

        Test-EXOConnection
        Send-AIEvent -Event "CmdRun"

        # Verify our UPN input
        [array]$UserArray = Test-UserObject -ToTest $UserPrincipalName

        foreach ($Object in $UserArray) {
            [string]$User = $Object.UserPrincipalName

            # Get the mailbox name (used previously)
            $MailboxName = (Get-Mailbox -Identity $User).Name

            Out-LogFile ("Searching for changes made to: " + $MailboxName) -action

            # Get all changes for this user from the Unified Audit Logs
            [array]$UserChanges = Search-UnifiedAuditLog -UserIds $User -StartDate $Hawk.StartDate -EndDate $Hawk.EndDate -RecordType ExchangeAdmin -Operations "*" -ResultSize 5000

            # If there are any results, handle them
            if ($UserChanges.Count -gt 0) {
                Out-LogFile ("Found " + $UserChanges.Count + " changes made to this user")

                # Determine the user's output folder
                $UserFolder = (Get-HawkUserPath -User $User)

                # Write raw AuditData JSON to a JSON file for verification
                $RawJsonPath = Join-Path $UserFolder "User_Changes_Raw.json"
                $UserChanges | Select-Object -ExpandProperty AuditData | Out-File $RawJsonPath

                # Also write raw data to a text file (similar to previous testing snippet)
                $RawTxtPath = Join-Path $UserFolder "User_Changes_Raw.txt"
                "User: $User" | Out-File $RawTxtPath
                $UserChanges | Select-Object -ExpandProperty AuditData | Out-File $RawTxtPath -Append
                "------------------------------------" | Out-File $RawTxtPath -Append

                # Parse the results with the new Get-SimpleUnifiedAuditLog function
                $ParsedChanges = $UserChanges | ForEach-Object {
                    $AuditDataJson = $_.AuditData
                    $AuditDataObj = $AuditDataJson | ConvertFrom-Json
                    $AuditDataObj
                } | Get-SimpleUnifiedAuditLog

                # Output the parsed results
                $ParsedChanges | Out-MultipleFileType -FilePrefix "Simple_User_Changes" -csv -json -User $User
                $UserChanges | Out-MultipleFileType -FilePrefix "User_Changes" -csv -json -User $User
            }
            else {
                Out-LogFile "No User Changes found."
            }
        }
    }
