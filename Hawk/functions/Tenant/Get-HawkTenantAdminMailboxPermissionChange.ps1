Function Get-HawkTenantAdminMailboxPermissionChange {
    <#
    .SYNOPSIS
        Retrieves audit log entries for mailbox permission changes within the tenant.

    .DESCRIPTION
        Searches the Unified Audit Log for mailbox permission changes and flags any grants
        of FullAccess, SendAs, or Send on Behalf permissions for investigations.
        Excludes normal system operations on Discovery Search Mailboxes.

    .OUTPUTS
        File: Simple_Mailbox_Permission_Change.csv/.json  
        Path: \Tenant  
        Description: Simplified view of mailbox permission changes.

        File: Mailbox_Permission_Change.csv/.json  
        Path: \Tenant  
        Description: Detailed audit log data for permission changes.

        File: _Investigate_Mailbox_Permission_Change.csv/.json  
        Path: \Tenant  
        Description: Permission changes that granted sensitive rights.

    .EXAMPLE
        Get-HawkTenantAdminMailboxPermissionChange

        Retrieves mailbox permission change events from the audit logs.
    #>
    [CmdletBinding()]
    param()

    # Check if Hawk object exists and is fully initialized
    if (Test-HawkGlobalObject) {
        Initialize-HawkGlobalObject
    }


    Test-EXOConnection
    Send-AIEvent -Event "CmdRun"

    Out-LogFile "Initiating collection of mailbox permission changes from the UAL." -Action

    # Create tenant folder if it doesn't exist
    $TenantPath = Join-Path -Path $Hawk.FilePath -ChildPath "Tenant"
    if (-not (Test-Path -Path $TenantPath)) {
        New-Item -Path $TenantPath -ItemType Directory -Force | Out-Null
    }

    try {
        # Search for mailbox permission changes
        Out-LogFile "Searching audit logs for mailbox permission changes" -action
        $searchCommand = "Search-UnifiedAuditLog -RecordType ExchangeAdmin -Operations 'Add-MailboxPermission','Add-RecipientPermission','Add-ADPermission'"
        [array]$PermissionChanges = Get-AllUnifiedAuditLogEntry -UnifiedSearch $searchCommand

        if ($PermissionChanges.Count -gt 0) {
            Out-LogFile ("Found " + $PermissionChanges.Count + " mailbox permission changes in audit logs") -Information

            # Process and output the results
            $ParsedChanges = $PermissionChanges | Get-SimpleUnifiedAuditLog
            if ($ParsedChanges) {
                # Output simple format for easy analysis
                $ParsedChanges | Out-MultipleFileType -FilePrefix "Simple_Mailbox_Permission_Change" -csv -json

                # Output full audit logs for complete record
                $PermissionChanges | Out-MultipleFileType -FilePrefix "Mailbox_Permission_Change" -csv -json

                # Check for sensitive permissions, excluding Discovery Search Mailbox system operations
                $SensitiveGrants = $ParsedChanges | Where-Object {
                    # First check if this is potentially sensitive permission
                    ($_.Param_AccessRights -match 'FullAccess|SendAs' -or
                     $_.Operation -eq 'Add-ADPermission' -or
                     $_.Operation -match 'Add-RecipientPermission') -and
                    # Then exclude DiscoverySearchMailbox system operations
                    -not (
                        $_.UserId -eq "NT AUTHORITY\SYSTEM (Microsoft.Exchange.ServiceHost)" -and 
                        $_.ObjectId -like "*DiscoverySearchMailbox*" -and
                        $_.Param_User -like "*Discovery Management*"
                    )
                }

                if ($SensitiveGrants) {
                    Out-LogFile "Found $($SensitiveGrants.Count) mailbox permission changes" -Notice
                    Out-LogFile "Please verify this activity is legitimate."-Notice
                    $SensitiveGrants | Out-MultipleFileType -FilePrefix "_Investigate_Mailbox_Permission_Change" -csv -json -Notice
                }
            }
            else {
                Out-LogFile "Error: Failed to parse mailbox permission audit data" -isError
            }
        }
        else {
            Out-LogFile "Get-HawkTenantAdminMailBoxPermissionChange completed successfully" -Information
            Out-LogFile "No mailbox permission changes found in audit logs" -action
        }
    }
    catch {
        Out-LogFile "Error analyzing mailbox permission changes: $($_.Exception.Message)" -isError
        Write-Error -ErrorRecord $_ -ErrorAction Continue
    }

    Out-LogFile "Completed collection of mailbox permission changes from the UAL." -Information

}