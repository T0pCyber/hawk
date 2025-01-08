function Get-HawkUserMailboxAuditing {
    <#
    .SYNOPSIS
        Gathers Mailbox Audit data if enabled for the user.

    .DESCRIPTION
        Retrieves mailbox audit logs from Microsoft 365 Unified Audit Log, focusing on mailbox
        content access and operations. This function replaces the deprecated Search-MailboxAuditLog
        cmdlet with modern UAL-based auditing.

        Migration Changes:
        - Old: Used Search-MailboxAuditLog for direct mailbox audit log access
        - New: Uses Search-UnifiedAuditLog with separate collection of:
          * ExchangeItem records (item-level operations)
          * ExchangeItemGroup records (access patterns)

        The new implementation provides:
        - Improved visibility into mailbox item access patterns
        - More consistent data collection across Exchange Online
        - Automatic pagination for large result sets
        - Integration with Microsoft 365 compliance center
        - Separated output files for better data analysis

        Note: Administrative actions on mailboxes (like granting permissions) are tracked by
        Get-HawkUserAdminAudit instead of this function.

    .PARAMETER UserPrincipalName
        Single UPN of a user, comma-separated list of UPNs, or array of objects that contain UPNs.

    .OUTPUTS
        ExchangeItem Records:
        File: ExchangeItem_Simple_{User}.csv/.json
        Path: \<User>
        Description: Flattened item-level operations data in CSV and JSON formats

        File: ExchangeItem_Logs_{User}.csv/.json
        Path: \<User>
        Description: Raw item-level operations data in CSV and JSON formats

        ExchangeItemGroup Records:
        File: ExchangeItemGroup_Simple_{User}.csv/.json
        Path: \<User>
        Description: Flattened access pattern data in CSV and JSON formats

        File: ExchangeItemGroup_Logs_{User}.csv/.json
        Path: \<User>
        Description: Raw access pattern data in CSV and JSON formats

    .EXAMPLE
        Get-HawkUserMailboxAuditing -UserPrincipalName user@contoso.com

        Search for all Mailbox Audit logs from user@contoso.com, creating separate files for
        item operations and access patterns, each with both raw and processed formats.

    .EXAMPLE
        Get-HawkUserMailboxAuditing -UserPrincipalName (Get-Mailbox -Filter {CustomAttribute1 -eq "C-level"})

        Search for all Mailbox Audit logs for all users who have "C-Level" set in CustomAttribute1,
        creating separate output files for each user's item operations and access patterns.

    .NOTES
        In older versions of Exchange Online, Search-MailboxAuditLog provided direct access to
        mailbox audit data. This has been replaced by the Unified Audit Log which provides a
        more comprehensive and consistent view of mailbox activities through separate record types:
        - ExchangeItem: Tracks specific operations on items
        - ExchangeItemGroup: Tracks access patterns and aggregated activity

        Each record type is processed separately and output in multiple formats to support
        different analysis needs:
        - Simple (flattened) formats for easy analysis
        - Raw formats for detailed investigation
        - JSON dumps for programmatic processing
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

        Out-LogFile ("Attempting to Gather Mailbox Audit logs for: " + $User) -action

        # Test if mailbox auditing is enabled
        $mbx = Get-Mailbox -Identity $User
        if ($mbx.AuditEnabled -eq $true) {
            Out-LogFile "Mailbox Auditing is enabled." -Information

            try {
                # Get the user's folder path
                $UserFolder = Join-Path -Path $Hawk.FilePath -ChildPath $User
                if (-not (Test-Path -Path $UserFolder)) {
                    New-Item -Path $UserFolder -ItemType Directory -Force | Out-Null
                }

                # Process ExchangeItem records
                Out-LogFile "Searching Unified Audit Log for ExchangeItem events." -action
                $searchCommand = "Search-UnifiedAuditLog -UserIds $User -RecordType ExchangeItem"
                $itemLogs = Get-AllUnifiedAuditLogEntry -UnifiedSearch $searchCommand

                if ($itemLogs.Count -gt 0) {
                    Out-LogFile ("Found " + $itemLogs.Count + " ExchangeItem events.") -Information

                    # Process and output flattened data
                    $ParsedItemLogs = $itemLogs | Get-SimpleUnifiedAuditLog
                    if ($ParsedItemLogs) {
                        $ParsedItemLogs | Out-MultipleFileType -FilePrefix "ExchangeItem_Simple" -csv -json -User $User
                    }

                    # Output raw data
                    $itemLogs | Out-MultipleFileType -FilePrefix "ExchangeItem_Logs" -csv -json -User $User
                }
                else {
                    Out-LogFile "No ExchangeItem events found." -Information
                }

                # Process ExchangeItemGroup records
                Out-LogFile "Searching Unified Audit Log for ExchangeItemGroup events." -action
                $searchCommand = "Search-UnifiedAuditLog -UserIds $User -RecordType ExchangeItemGroup"
                $groupLogs = Get-AllUnifiedAuditLogEntry -UnifiedSearch $searchCommand

                if ($groupLogs.Count -gt 0) {
                    Out-LogFile ("Found " + $groupLogs.Count + " ExchangeItemGroup events.") -Information

                    # Process and output flattened data
                    $ParsedGroupLogs = $groupLogs | Get-SimpleUnifiedAuditLog
                    if ($ParsedGroupLogs) {
                        $ParsedGroupLogs | Out-MultipleFileType -FilePrefix "ExchangeItemGroup_Simple" -csv -json -User $User
                    }

                    # Output raw data
                    $groupLogs | Out-MultipleFileType -FilePrefix "ExchangeItemGroup_Logs" -csv -json -User $User
                }
                else {
                    Out-LogFile "No ExchangeItemGroup events found." -Information
                }

                # Summary logging
                $totalEvents = ($itemLogs.Count + $groupLogs.Count)
                Out-LogFile "Completed processing $totalEvents total events." -Information
            }
            catch {
                Out-LogFile "Error retrieving audit logs: $($_.Exception.Message)" -isError
                Write-Error -ErrorRecord $_ -ErrorAction Continue
            }
        }
        else {
            Out-LogFile ("Auditing not enabled for " + $User) -Information
            Out-LogFile "Enable auditing to track mailbox access patterns." -Information
        }
    }
}