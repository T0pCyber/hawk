Function Get-HawkTenantAdminInboxRuleRemoval {
    <#
    .SYNOPSIS
        Retrieves audit log entries for inbox rules that were removed within the tenant.

    .DESCRIPTION
        This function queries the Microsoft 365 Unified Audit Log for events classified as inbox 
        rule removal (Remove-InboxRule). It focuses on historical record-keeping and identifying 
        when inbox rules were removed and by whom. The logged events do not indicate the 
        specific method or interface used to remove the rules.

        Key points:
        - Displays removal events for inbox rules, including who removed them and when.
        - Flags removals that might be suspicious (e.g., rules that were forwarding externally).
        - Provides historical context for rule removals during investigations.

        For current, active rules, use Get-HawkTenantInboxRules.

    .OUTPUTS
        File: Simple_Admin_Inbox_Rules_Removal.csv/.json  
        Path: \Tenant  
        Description: Simplified view of removed inbox rule events.

        File: Admin_Inbox_Rules_Removal.csv/.json  
        Path: \Tenant  
        Description: Detailed audit log data for removed inbox rules.

        File: _Investigate_Admin_Inbox_Rules_Removal.csv/.json  
        Path: \Tenant  
        Description: A subset of historically removed rules flagged as suspicious.

    .EXAMPLE
        Get-HawkTenantAdminInboxRuleRemoval

        Retrieves events for all removed inbox rules from the audit logs within the specified 
        search window, highlighting any that appear suspicious.
    #>
    [CmdletBinding()]
    param()

    # Check if Hawk object exists and is fully initialized
    if (Test-HawkGlobalObject) {
        Initialize-HawkGlobalObject
    }

    Test-EXOConnection
    Send-AIEvent -Event "CmdRun"

    Out-LogFile "Initiating collection of admin inbox rule removal events from the UAL." -Action

    # Create tenant folder if it doesn't exist
    $TenantPath = Join-Path -Path $Hawk.FilePath -ChildPath "Tenant"
    if (-not (Test-Path -Path $TenantPath)) {
        New-Item -Path $TenantPath -ItemType Directory -Force | Out-Null
    }

    try {
        # Search for removed inbox rules
        Out-LogFile "Searching audit logs for inbox rule removals" -action
        $searchCommand = "Search-UnifiedAuditLog -RecordType ExchangeAdmin -Operations 'Remove-InboxRule'"
        [array]$RemovedInboxRules = Get-AllUnifiedAuditLogEntry -UnifiedSearch $searchCommand

        if ($RemovedInboxRules.Count -gt 0) {
            Out-LogFile ("Found " + $RemovedInboxRules.Count + " admin inbox rule removals in audit logs") -Information

            # Process and output the results
            $ParsedRules = $RemovedInboxRules | Get-SimpleUnifiedAuditLog
            if ($ParsedRules) {
                # Output simple format for easy analysis
                $ParsedRules | Out-MultipleFileType -FilePrefix "Simple_Admin_Inbox_Rules_Removal" -csv -json

                # Output full audit logs for complete record
                $RemovedInboxRules | Out-MultipleFileType -FilePrefix "Admin_Inbox_Rules_Removal" -csv -json

                # Check for suspicious removals
                $SuspiciousRemovals = $ParsedRules | Where-Object {
                    $reasons = @()
                    Test-SuspiciousInboxRule -Rule $_ -Reasons ([ref]$reasons)
                }

                if ($SuspiciousRemovals) {
                    Out-LogFile "Found $($SuspiciousRemovals.Count) inbox rule removal events" -Notice
                    Out-LogFile "Please verify this activity is legitimate." -Notice
                    $SuspiciousRemovals | Out-MultipleFileType -FilePrefix "_Investigate_Admin_Inbox_Rules_Removal" -csv -json -Notice
                }
            }
            else {
                Out-LogFile "Error: Failed to parse inbox rule removal audit data" -isError
            }
        }
        else {
            Out-LogFile "Get-HawkTenantAdminInboxRuleRemoval completed successfully" -Information
            Out-LogFile "No inbox rule removals found in audit logs" -action
        }
    }
    catch {
        Out-LogFile "Error analyzing admin inbox rule removals: $($_.Exception.Message)" -isError
        Write-Error -ErrorRecord $_ -ErrorAction Continue
    }


    Out-LogFile "Completed collection of admin inbox rule removal events from the UAL." -Information

}