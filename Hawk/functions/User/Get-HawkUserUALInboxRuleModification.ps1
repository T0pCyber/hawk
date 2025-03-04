Function Get-HawkUserUALInboxRuleModification {
    <#
    .SYNOPSIS
        Retrieves audit log entries for inbox rules that were historically modified by or for a specific user.

    .DESCRIPTION
        This function queries the Microsoft 365 Unified Audit Log for inbox rule modification events 
        (Set-InboxRule) associated with a specific user or set of users. It focuses on historical 
        changes to existing rules, helping identify suspicious modifications (e.g., forwarding to 
        external addresses, enabling deletion, or targeting sensitive keywords).

        The logged events do not indicate how or where the modification took place, only that 
        an inbox rule was changed at a given time by a specific account.

        Key points:
        - Shows modification events for inbox rules, including who modified them and when.
        - Flags modifications that may be suspicious based on predefined criteria.
        - Does not indicate whether the rules are currently active or still exist.

        For current, active rules, use Get-HawkUserInboxRule instead.

        This function is the user-specific counterpart to Get-HawkTenantAdminInboxRuleModification.

    .PARAMETER UserPrincipalName
        Single UPN of a user, comma-separated list of UPNs, or array of objects that contain UPNs.
        This parameter specifies which users' inbox rule modification events to investigate.

    .OUTPUTS
        File: Simple_User_Inbox_Rules_Modification_<user>.csv/.json  
        Path: \<User>  
        Description: Simplified view of inbox rule modification events for the user.

        File: User_Inbox_Rules_Modification_<user>.csv/.json  
        Path: \<User>  
        Description: Detailed audit log data for modified inbox rules for the user.

        File: _Investigate_User_Inbox_Rules_Modification_<user>.csv/.json  
        Path: \<User>  
        Description: A subset of historically modified rules flagged as suspicious.

    .EXAMPLE
        Get-HawkUserUALInboxRuleModification -UserPrincipalName user@contoso.com

        Retrieves inbox rule modification events from the audit logs for user@contoso.com.
        
    .EXAMPLE
        Get-HawkUserUALInboxRuleModification -UserPrincipalName (Get-Mailbox -Filter {CustomAttribute1 -eq "C-level"})

        Retrieves inbox rule modification events for all users with CustomAttribute1 set to "C-level".
        
    .LINK
        Get-HawkTenantAdminInboxRuleModification
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

        Out-LogFile "Initiating collection of inbox rule modification events for $User from the UAL." -Action

        try {
            # Build search command for unified audit log - specific to this user
            $searchCommand = "Search-UnifiedAuditLog -RecordType ExchangeAdmin -Operations 'Set-InboxRule' -UserIds $User"
            [array]$ModifiedInboxRules = Get-AllUnifiedAuditLogEntry -UnifiedSearch $searchCommand

            if ($ModifiedInboxRules.Count -gt 0) {
                Out-LogFile ("Found " + $ModifiedInboxRules.Count + " inbox rule modification events for $User in the audit logs.") -Information

                # Process and output the results
                $ParsedRules = $ModifiedInboxRules | Get-SimpleUnifiedAuditLog
                
                if ($ParsedRules) {
                    Out-LogFile "Writing parsed inbox rule modification data." -Action
                    $ParsedRules | Out-MultipleFileType -FilePrefix "Simple_User_Inbox_Rules_Modification" -csv -json -User $User
                    $ModifiedInboxRules | Out-MultipleFileType -FilePrefix "User_Inbox_Rules_Modification" -csv -json -User $User

                    # Check for suspicious modifications using the helper function
                    $SuspiciousModifications = $ParsedRules | Where-Object {
                        $reasons = @()
                        Test-SuspiciousInboxRule -Rule $_ -Reasons ([ref]$reasons)
                    }

                    if ($SuspiciousModifications) {
                        Out-LogFile "Found $($SuspiciousModifications.Count) suspicious inbox rule modification events for $User." -Notice
                        Out-LogFile "Please verify this activity is legitimate." -Notice
                        $SuspiciousModifications | Out-MultipleFileType -FilePrefix "_Investigate_User_Inbox_Rules_Modification" -csv -json -User $User -Notice
                    }
                }
                else {
                    Out-LogFile "Error: Failed to parse inbox rule modification audit data for $User." -isError
                }
            }
            else {
                Out-LogFile "No inbox rule modification events found in audit logs for $User." -Information
            }
        }
        catch {
            Out-LogFile "Error analyzing inbox rule modifications for $User : $_" -isError
            Write-Error -ErrorRecord $_ -ErrorAction Continue
        }

        Out-LogFile "Completed collection of inbox rule modification events for $User from the UAL." -Information
    }
}