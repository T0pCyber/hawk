Function Get-HawkUserUALInboxRuleRemoval {
    <#
    .SYNOPSIS
        Retrieves audit log entries for inbox rules that were removed by or for a specific user.

    .DESCRIPTION
        This function queries the Microsoft 365 Unified Audit Log for inbox rule removal events 
        (Remove-InboxRule) associated with a specific user or set of users. It focuses on 
        historical record-keeping and identifying when inbox rules were removed and by whom.
        
        The logged events do not indicate the specific method or interface used to remove the rules,
        only that a rule was removed at a given time by a specific account.

        Key points:
        - Displays removal events for inbox rules, including who removed them and when.
        - Flags removals that might be suspicious (e.g., rules that were forwarding externally).
        - Provides historical context for rule removals during investigations.

        For current, active rules, use Get-HawkUserInboxRule instead.

        This function is the user-specific counterpart to Get-HawkTenantAdminInboxRuleRemoval.

    .PARAMETER UserPrincipalName
        Single UPN of a user, comma-separated list of UPNs, or array of objects that contain UPNs.
        This parameter specifies which users' inbox rule removal events to investigate.

    .OUTPUTS
        File: Simple_User_Inbox_Rules_Removal_<user>.csv/.json  
        Path: \<User>  
        Description: Simplified view of removed inbox rule events for the user.

        File: User_Inbox_Rules_Removal_<user>.csv/.json  
        Path: \<User>  
        Description: Detailed audit log data for removed inbox rules for the user.

        File: _Investigate_User_Inbox_Rules_Removal_<user>.csv/.json  
        Path: \<User>  
        Description: A subset of historically removed rules flagged as suspicious.

    .EXAMPLE
        Get-HawkUserUALInboxRuleRemoval -UserPrincipalName user@contoso.com

        Retrieves inbox rule removal events from the audit logs for user@contoso.com.
        
    .EXAMPLE
        Get-HawkUserUALInboxRuleRemoval -UserPrincipalName (Get-Mailbox -Filter {CustomAttribute1 -eq "C-level"})

        Retrieves inbox rule removal events for all users with CustomAttribute1 set to "C-level".
        
    .LINK
        Get-HawkTenantAdminInboxRuleRemoval
        Get-HawkUserInboxRule
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [array]$UserPrincipalName
    )

    # Check if Hawk object exists and is fully initialized
    if (Test-HawkGlobalObject) {
        Initialize-HawkGlobalObject
    }

    Test-EXOConnection
    Send-AIEvent -Event "CmdRun"

    # Verify our UPN input
    [array]$UserArray = Test-UserObject -ToTest $UserPrincipalName

    foreach ($Object in $UserArray) {
        [string]$User = $Object.UserPrincipalName

        Out-LogFile "Initiating collection of inbox rule removal events for $User from the UAL." -Action

        try {
            # Build search command for unified audit log - specific to this user
            $searchCommand = "Search-UnifiedAuditLog -RecordType ExchangeAdmin -Operations 'Remove-InboxRule' -UserIds $User"
            [array]$RemovedInboxRules = Get-AllUnifiedAuditLogEntry -UnifiedSearch $searchCommand

            if ($RemovedInboxRules.Count -gt 0) {
                Out-LogFile ("Found " + $RemovedInboxRules.Count + " inbox rule removal events for $User in the audit logs.") -Information

                # Process and output the results
                $ParsedRules = $RemovedInboxRules | Get-SimpleUnifiedAuditLog
                
                if ($ParsedRules) {
                    # Output simple format for easy analysis
                    $ParsedRules | Out-MultipleFileType -FilePrefix "Simple_User_Inbox_Rules_Removal" -csv -json -User $User
                    
                    # Output full audit logs for complete record
                    $RemovedInboxRules | Out-MultipleFileType -FilePrefix "User_Inbox_Rules_Removal" -csv -json -User $User

                    # Check for suspicious removals using the helper function
                    $SuspiciousRemovals = $ParsedRules | Where-Object {
                        $reasons = @()
                        Test-SuspiciousInboxRule -Rule $_ -Reasons ([ref]$reasons)
                    }

                    if ($SuspiciousRemovals) {
                        Out-LogFile "Found $($SuspiciousRemovals.Count) suspicious inbox rule removal events for $User." -Notice
                        Out-LogFile "Please verify this activity is legitimate." -Notice
                        $SuspiciousRemovals | Out-MultipleFileType -FilePrefix "_Investigate_User_Inbox_Rules_Removal" -csv -json -User $User -Notice
                    }
                }
                else {
                    Out-LogFile "Error: Failed to parse inbox rule removal audit data for $User." -isError
                }
            }
            else {
                Out-LogFile "No inbox rule removal events found in audit logs for $User." -Information
            }
        }
        catch {
            Out-LogFile "Error analyzing inbox rule removals for $User : $_" -isError
            Write-Error -ErrorRecord $_ -ErrorAction Continue
        }

        Out-LogFile "Completed collection of inbox rule removal events for $User from the UAL." -Information
    }
}