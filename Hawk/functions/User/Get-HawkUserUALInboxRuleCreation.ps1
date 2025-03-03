Function Get-HawkUserUALInboxRuleCreation {
    <#
    .SYNOPSIS
        Retrieves audit log entries for inbox rules that were historically created by or for a specific user.

    .DESCRIPTION
        This function queries the Microsoft 365 Unified Audit Log for inbox rule creation events 
        (New-InboxRule) associated with a specific user or set of users. It focuses on historical 
        record-keeping and identifying potentially suspicious rules that were created.

        Key points:
        - Displays creation events for inbox rules, including who created them and when.
        - Flags created rules that appear suspicious (e.g., rules that forward externally, delete 
          messages, or filter based on suspicious keywords).
        - Does not confirm whether the rules are currently active or still exist.

        For current, active rules, use Get-HawkUserInboxRule instead.

        This function is the user-specific counterpart to Get-HawkTenantAdminInboxRuleCreation.

    .PARAMETER UserPrincipalName
        Single UPN of a user, comma-separated list of UPNs, or array of objects that contain UPNs.
        This parameter specifies which users' inbox rule creation events to investigate.

    .OUTPUTS
        File: Simple_User_Inbox_Rules_Creation_<user>.csv/.json  
        Path: \<User>  
        Description: Simplified view of created inbox rule events for the user.

        File: User_Inbox_Rules_Creation_<user>.csv/.json  
        Path: \<User>  
        Description: Detailed audit log data for created inbox rules for the user.

        File: _Investigate_User_Inbox_Rules_Creation_<user>.csv/.json  
        Path: \<User>  
        Description: A subset of historically created rules flagged as suspicious.

    .EXAMPLE
        Get-HawkUserUALInboxRuleCreation -UserPrincipalName user@contoso.com

        Retrieves inbox rule creation events from the audit logs for user@contoso.com.
        
    .EXAMPLE
        Get-HawkUserUALInboxRuleCreation -UserPrincipalName (Get-Mailbox -Filter {CustomAttribute1 -eq "C-level"})

        Retrieves inbox rule creation events for all users with CustomAttribute1 set to "C-level".
        
    .LINK
        Get-HawkTenantAdminInboxRuleCreation
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

        Out-LogFile "Initiating collection of inbox rule creation events for $User from the UAL." -Action

        try {
            # Build search command for unified audit log - specific to this user
            $searchCommand = "Search-UnifiedAuditLog -RecordType ExchangeAdmin -Operations 'New-InboxRule' -UserIds $User"
            [array]$NewInboxRules = Get-AllUnifiedAuditLogEntry -UnifiedSearch $searchCommand

            if ($NewInboxRules.Count -gt 0) {
                Out-LogFile ("Found " + $NewInboxRules.Count + " inbox rule creation events for $User in the audit logs.") -Information

                # Process and output the results
                $ParsedRules = $NewInboxRules | Get-SimpleUnifiedAuditLog
                
                if ($ParsedRules) {
                    Out-LogFile "Writing parsed inbox rule creation data." -Action
                    $ParsedRules | Out-MultipleFileType -FilePrefix "Simple_User_Inbox_Rules_Creation" -csv -json -User $User
                    $NewInboxRules | Out-MultipleFileType -FilePrefix "User_Inbox_Rules_Creation" -csv -json -User $User

                    # Check for suspicious rules using the helper function
                    $SuspiciousRules = $ParsedRules | Where-Object {
                        $reasons = @()
                        Test-SuspiciousInboxRule -Rule $_ -Reasons ([ref]$reasons)
                    }

                    if ($SuspiciousRules) {
                        Out-LogFile "Found $($SuspiciousRules.Count) suspicious inbox rule creation events for $User." -Notice
                        Out-LogFile "Please verify this activity is legitimate." -Notice
                        $SuspiciousRules | Out-MultipleFileType -FilePrefix "_Investigate_User_Inbox_Rules_Creation" -csv -json -User $User -Notice
                    }
                }
                else {
                    Out-LogFile "Error: Failed to parse inbox rule audit data for $User." -isError
                }
            }
            else {
                Out-LogFile "No inbox rule creation events found in audit logs for $User." -Information
            }
        }
        catch {
            Out-LogFile "Error analyzing inbox rule creation for $User : $_" -isError
            Write-Error -ErrorRecord $_ -ErrorAction Continue
        }

        Out-LogFile "Completed collection of inbox rule creation events for $User from the UAL." -Information
    }
}