Function Get-HawkUserAdminAudit {
    <#
    .SYNOPSIS
        Searches the Unified Audit logs for any commands that were run against the provided user object.
    .DESCRIPTION
        Searches the Unified Audit logs for any commands that were run against the provided user object.
        Uses Get-AllUnifiedAuditLogEntry to ensure complete retrieval of all audit records within the
        specified search period, handling pagination and large result sets automatically.

    .PARAMETER UserPrincipalName
        UserPrincipalName of the user you're investigating. Can be a single UPN, comma-separated list,
        or array of objects containing UPNs.

    .OUTPUTS
        File: Simple_User_Changes.csv
        Path: \<user>
        Description: All cmdlets that were run against the user in a simple format.

        File: User_Changes.csv
        Path: \<user>
        Description: Raw data of all changes made to the user.

    .EXAMPLE
        Get-HawkUserAdminAudit -UserPrincipalName user@company.com

        Gets all changes made to user@company.com and outputs them to the csv and json files.

    .EXAMPLE
        Get-HawkUserAdminAudit -UserPrincipalName (Get-Mailbox -Filter {CustomAttribute1 -eq "VIP"})

        Gets admin audit data for all mailboxes with CustomAttribute1 set to "VIP".
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

        try {
            # Build search command for Get-AllUnifiedAuditLogEntry
            $searchCommand = "Search-UnifiedAuditLog -UserIds $User -RecordType ExchangeAdmin -Operations '*'"

            # Get all changes for this user using Get-AllUnifiedAuditLogEntry
            [array]$UserChanges = Get-AllUnifiedAuditLogEntry -UnifiedSearch $searchCommand

            # If there are any results process and output them
            if ($UserChanges.Count -gt 0) {
                Out-LogFile ("Found " + $UserChanges.Count + " changes made to this user") -Information

                # Get the user's output folder path
                $UserFolder = Join-Path -Path $Hawk.FilePath -ChildPath $User

                # Ensure user folder exists
                if (-not (Test-Path -Path $UserFolder)) {
                    New-Item -Path $UserFolder -ItemType Directory -Force | Out-Null
                }

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
                Out-LogFile "No User Changes found." -Information
            }
        }
        catch {
            Out-LogFile "Error processing audit logs for $User : $_" -isError
            Write-Error -ErrorRecord $_ -ErrorAction Continue
        }
    }
}