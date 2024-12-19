Function Get-HawkTenantAdminInboxRuleModification {
    <#
    .SYNOPSIS
        Retrieves audit log entries for inbox rules that were historically modified within the tenant.

    .DESCRIPTION
        This function queries the Microsoft 365 Unified Audit Logs for events classified as 
        inbox rule modifications (Set-InboxRule). It focuses on past changes to existing rules, 
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
        File: Simple_Admin_Inbox_Rules_Modification_History.csv/.json  
        Path: \Tenant  
        Description: Simplified view of inbox rule modification events.

        File: Admin_Inbox_Rules_Modification_History.csv/.json  
        Path: \Tenant  
        Description: Detailed audit log data for modified inbox rules.

        File: _Investigate_Admin_Inbox_Rules_Modification_History.csv/.json  
        Path: \Tenant  
        Description: A subset of historically modified rules flagged as suspicious.

        File: Investigate_Admin_Inbox_Rules_Modification_History_Raw.json  
        Path: \Tenant  
        Description: Raw audit data for suspicious rule modifications.

    .EXAMPLE
        Get-HawkTenantAdminInboxRuleModification

        Retrieves events for all modified inbox rules from the audit logs within the specified 
        search window, highlighting any that appear suspicious.

    .NOTES
        - Focuses solely on historical rule modification events.
        - Does not show if the rules currently exist or are active.
        - Does not specify the interface or method used to modify the rules.
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
        Out-LogFile "Searching audit logs for admin inbox rule modifications" -action
        $searchCommand = "Search-UnifiedAuditLog -RecordType ExchangeAdmin -Operations 'Set-InboxRule'"
        [array]$ModifiedInboxRules = Get-AllUnifiedAuditLogEntry -UnifiedSearch $searchCommand

        if ($ModifiedInboxRules.Count -gt 0) {
            Out-LogFile ("Found " + $ModifiedInboxRules.Count + " admin inbox rule modifications in audit logs")

            # Write raw audit data for reference
            $RawJsonPath = Join-Path -Path $TenantPath -ChildPath "Admin_Inbox_Rules_Modification_History_Raw.json"
            $ModifiedInboxRules | Select-Object -ExpandProperty AuditData | Out-File -FilePath $RawJsonPath

            # Process and output the results
            $ParsedRules = $ModifiedInboxRules | Get-SimpleUnifiedAuditLog
            if ($ParsedRules) {
                # Output simple format for easy analysis
                $ParsedRules | Out-MultipleFileType -FilePrefix "Simple_Admin_Inbox_Rules_Modification_History" -csv -json

                # Output full audit logs for complete record
                $ModifiedInboxRules | Out-MultipleFileType -FilePrefix "Admin_Inbox_Rules_Modification_History" -csv -json

                # Check for suspicious modifications
                $SuspiciousModifications = $ParsedRules | Where-Object {
                    $rule = $_
                    
                    # Check for forwarding/redirection
                    ($rule.Param_ForwardTo) -or
                    ($rule.Param_ForwardAsAttachmentTo) -or
                    ($rule.Param_RedirectTo) -or
                    ($rule.Param_DeleteMessage) -or

                    # Check for moves to deleted items
                    ($rule.Param_MoveToFolder -eq 'Deleted Items') -or

                    # Check for suspicious keywords in subject filters
                    ($rule.Param_SubjectContainsWords -match 'password|credentials|login|secure|security') -or

                    # Check for security-related sender filters
                    ($rule.Param_From -match 'security|admin|support|microsoft|helpdesk')
                }

                if ($SuspiciousModifications) {
                    Out-LogFile "Found suspicious rule modifications requiring investigation" -Notice
                    $SuspiciousModifications | Out-MultipleFileType -FilePrefix "_Investigate_Admin_Inbox_Rules_Modification_History" -csv -json -Notice

                    # Write raw data for suspicious modifications
                    $RawSuspiciousPath = Join-Path -Path $TenantPath -ChildPath "Investigate_Admin_Inbox_Rules_Modification_History_Raw.json"
                    $SuspiciousModifications | ConvertTo-Json -Depth 10 | Out-File -FilePath $RawSuspiciousPath

                    # Log details about why each modification was flagged
                    foreach ($rule in $SuspiciousModifications) {
                        $reasons = @()
                        if ($rule.Param_ForwardTo) { $reasons += "modified forwarding to: $($rule.Param_ForwardTo)" }
                        if ($rule.Param_ForwardAsAttachmentTo) { $reasons += "modified forwarding as attachment to: $($rule.Param_ForwardAsAttachmentTo)" }
                        if ($rule.Param_RedirectTo) { $reasons += "modified redirection to: $($rule.Param_RedirectTo)" }
                        if ($rule.Param_DeleteMessage) { $reasons += "enabled message deletion" }
                        if ($rule.Param_MoveToFolder -eq 'Deleted Items') { $reasons += "modified to move to Deleted Items" }
                        if ($rule.Param_SubjectContainsWords -match 'password|credentials|login|secure|security') {
                            $reasons += "modified suspicious subject filter: $($rule.Param_SubjectContainsWords)"
                        }
                        if ($rule.Param_From -match 'security|admin|support|microsoft|helpdesk') {
                            $reasons += "modified to target security sender: $($rule.Param_From)"
                        }

                        Out-LogFile "Found suspicious rule modification: '$($rule.Param_Name)' modified by $($rule.UserId) at $($rule.CreationTime)" -Notice
                        Out-LogFile "Reasons for investigation: $($reasons -join '; ')" -Notice 
                    }
                }
            }
            else {
                Out-LogFile "Error: Failed to parse inbox rule audit data" -Notice
            }
        }
        else {
            Out-LogFile "No admin inbox rule modifications found in audit logs"
        }
    }
    catch {
        Out-LogFile "Error analyzing admin inbox rule modifications: $($_.Exception.Message)" -Notice
        Write-Error -ErrorRecord $_ -ErrorAction Continue
    }
}