Function Get-HawkTenantAdminInboxRuleModification {
    <#
    .SYNOPSIS
        Retrieves audit log entries for inbox rules that were historically modified within the tenant.

    .DESCRIPTION
        This function queries the Microsoft 365 Unified Audit Logs for events classified as 
        inbox rule modification (Set-InboxRule). It focuses on past changes to existing rules, 
        helping identify suspicious modifications (e.g., forwarding to external addresses, 
        enabling deletion, or targeting sensitive keywords).

        The logged events do not indicate how or where the modification took place, only that 
        an inbox rule was changed at a given time by a specific account.

        Key points:
        - Shows modification events for inbox rules, including who modified them and when.
        - Flags modifications that may be suspicious based on predefined criteria.
        - Does not indicate whether the rules are currently active or still exist.

        For current, active rules, use Get-HawkTenantInboxRules.

    .OUTPUTS
        File: Simple_Admin_Inbox_Rules_Modification.csv/.json  
        Path: \Tenant  
        Description: Simplified view of inbox rule modification events.

        File: Admin_Inbox_Rules_Modification.csv/.json  
        Path: \Tenant  
        Description: Detailed audit log data for modified inbox rules.

        File: _Investigate_Admin_Inbox_Rules_Modification.csv/.json  
        Path: \Tenant  
        Description: A subset of historically modified rules flagged as suspicious.

        File: Investigate_Admin_Inbox_Rules_Modification_Raw.json  
        Path: \Tenant  
        Description: Raw audit data for suspicious rule modifications.
    .EXAMPLE
        Get-HawkTenantAdminInboxRuleModification

        Retrieves events for all admin inbox rules modified and available within the audit logs within the configured search window.
        
        Remarks: This basic example pulls all inbox rule modification logs from the audit log and analyzes them for
        suspicious patterns. Output files will be created in the configured Hawk output directory under
        the Tenant subfolder.
    #>
    #>
    [CmdletBinding()]
    param()

    Test-EXOConnection
    Send-AIEvent -Event "CmdRun"

    Out-LogFile "Analyzing admin inbox rule modifications from audit logs" -Action

    # Create tenant folder if it doesn't exist
    $TenantPath = Join-Path -Path $Hawk.FilePath -ChildPath "Tenant"
    if (-not (Test-Path -Path $TenantPath)) {
        New-Item -Path $TenantPath -ItemType Directory -Force | Out-Null
    }

    try {
        # Search for modified inbox rules
        Out-LogFile "Searching audit logs for inbox rule modification events" -Action
        $searchCommand = "Search-UnifiedAuditLog -RecordType ExchangeAdmin -Operations 'Set-InboxRule'"
        [array]$ModifiedInboxRules = Get-AllUnifiedAuditLogEntry -UnifiedSearch $searchCommand

        if ($ModifiedInboxRules.Count -gt 0) {
            Out-LogFile ("Found " + $ModifiedInboxRules.Count + " admin inbox rule modifications in audit logs") -Information

            # Write raw audit data with action flag
            $RawJsonPath = Join-Path -Path $TenantPath -ChildPath "Admin_Inbox_Rules_Modification_Raw.json"
            Out-LogFile "Writing raw audit data to: $RawJsonPath" -Action
            $ModifiedInboxRules | Select-Object -ExpandProperty AuditData | Out-File -FilePath $RawJsonPath

            # Process and output the results
            $ParsedRules = $ModifiedInboxRules | Get-SimpleUnifiedAuditLog
            if ($ParsedRules) {
                Out-LogFile "Writing parsed admin inbox rule modification data" -Action
                $ParsedRules | Out-MultipleFileType -FilePrefix "Simple_Admin_Inbox_Rules_Modification" -csv -json
                $ModifiedInboxRules | Out-MultipleFileType -FilePrefix "Admin_Inbox_Rules_Modification" -csv -json

                # Check for suspicious modifications using the helper function
                $SuspiciousModifications = $ParsedRules | Where-Object {
                    $reasons = @()
                    Test-SuspiciousInboxRule -Rule $_ -Reasons ([ref]$reasons)
                }

                if ($SuspiciousModifications) {
                    Out-LogFile "Found suspicious rule modifications requiring investigation" -Notice

                    Out-LogFile "Writing suspicious rule modification data" -Action
                    $SuspiciousModifications | Out-MultipleFileType -FilePrefix "_Investigate_Admin_Inbox_Rules_Modification" -csv -json -Notice

                    # Write raw data for suspicious modifications with action flag
                    $RawSuspiciousPath = Join-Path -Path $TenantPath -ChildPath "Investigate_Admin_Inbox_Rules_Modification_Raw.json"
                    Out-LogFile "Writing raw suspicious modification data to: $RawSuspiciousPath" -Action
                    $SuspiciousModifications | ConvertTo-Json -Depth 10 | Out-File -FilePath $RawSuspiciousPath

                    # Log details about why each modification was flagged
                    foreach ($rule in $SuspiciousModifications) {
                        $reasons = @()
                        if (Test-SuspiciousInboxRule -Rule $rule -Reasons ([ref]$reasons)) {
                            Out-LogFile "Found suspicious rule modification: '$($rule.Param_Name)' modified by $($rule.UserId) at $($rule.CreationTime)" -Notice
                            Out-LogFile "Reasons for investigation: $($reasons -join '; ')" -Notice
                        }
                    }
                }
            }
            else {
                Out-LogFile "Error: Failed to parse inbox rule audit data" -isError
            }
        }
        else {
            Out-LogFile "No inbox rule modifications found in audit logs" -Information
        }
    }
    catch {
        Out-LogFile "Error analyzing admin inbox rule modifications: $($_.Exception.Message)" -isError
        Write-Error -ErrorRecord $_ -ErrorAction Continue
    }
}