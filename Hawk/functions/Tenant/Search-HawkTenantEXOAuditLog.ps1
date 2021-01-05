# RBAC Changes
# Changes to impersonation
Function Search-HawkTenantEXOAuditLog {

    <#
 
	.SYNOPSIS
	Searches the admin audit logs for possible bad actor activities

	.DESCRIPTION
	Searches the Exchange admin audkit logs for a number of possible bad actor activies.
	
	* New inbox rules
	* Changes to user forwarding configurations
	* Changes to user mailbox permissions
	* Granting of impersonation rights
			
	.OUTPUTS

	File: Simple_New_InboxRule.csv
	Path: \
	Description: cmdlets to create any new inbox rules in a simple to read format
	
	File: New_InboxRules.xml
	Path: \XML
	Description: Search results for any new inbox rules in CLI XML format

	File: _Investigate_Simple_New_InboxRule.csv
	Path: \
	Description: cmdlets to create inbox rules that forward or delete email in a simple format

	File: _Investigate_New_InboxRules.xml
	Path: \XML
	Description: Search results for newly created inbox rules that forward or delete email in CLI XML
	
	File: _Investigate_New_InboxRules.txt
	Path: \
	Description: Search results of newly created inbox rules that forward or delete email

	File: Simple_Forwarding_Changes.csv
	Path: \
	Description: cmdlets that change forwarding settings in a simple to read format

	File: Forwarding_Changes.xml
	Path: \XML
	Description: Search results for cmdlets that change forwarding settings in CLI XML
	
	File: Forwarding_Recipients.csv
	Path: \
	Description: List of unique Email addresses that were setup to recieve email via forwarding

	File: Simple_Mailbox_Permissions.csv
	Path: \
	Description: Cmdlets that add permissions to users in a simple to read format

	File: Mailbox_Permissions.xml
	Path: \XML
	Description: Search results for cmdlets that change permissions in CLI XML

	File: _Investigate_Impersonation_Roles.csv
	Path: \
	Description: List all users with impersonation rights if we find more than the default of one

	File: _Investigate_Impersonation_Roles.csv
	Path: \XML
	Description: List all users with impersonation rights if we find more than the default of one as CLI XML

	File: Impersonation_Rights.csv
	Path: \
	Description: List all users with impersonation rights if we only find the default one

	File: Impersonation_Rights.csv
	Path: \XML
	Description: List all users with impersonation rights if we only find the default one as CLI XML
	
	.EXAMPLE
	Search-HawkTenantEXOAuditLog 

	Searches the tenant audit logs looking for changes that could have been made in the tenant.
	
	#>

    Test-EXOConnection
    Send-AIEvent -Event "CmdRun"

    Out-LogFile "Searching EXO Audit Logs" -Action 
    Out-LogFile "Searching Entire Admin Audit Log for Specific cmdlets"

    #Make sure our values are null
    $TenantInboxRules = $Null
    $TenantSetInboxRules = $Null
    $TenantRemoveInboxRules = $Null

    
    # Search for the creation of ANY inbox rules    
    Out-LogFile "Searching for ALL Inbox Rules Created in the Shell" -action
    [array]$TenantInboxRules = Search-AdminAuditLog -Cmdlets New-InboxRule -StartDate $Hawk.StartDate -EndDate $Hawk.EndDate
	
    # If we found anything report it and log it
    if ($TenantInboxRules.count -gt 0) {
	
        Out-LogFile ("Found " + $TenantInboxRules.count + " Inbox Rule(s) created from PowerShell")
        $TenantInboxRules | Get-SimpleAdminAuditLog | Out-MultipleFileType -fileprefix "Simple_New_InboxRule" -csv
        $TenantInboxRules | Out-MultipleFileType -fileprefix "New_InboxRules" -csv
    }
    
    # Search for the Modification of ANY inbox rules    
    Out-LogFile "Searching for ALL Inbox Rules Modified in the Shell" -action
    [array]$TenantSetInboxRules = Search-AdminAuditLog -Cmdlets Set-InboxRule -StartDate $Hawk.StartDate -EndDate $Hawk.EndDate
        
    # If we found anything report it and log it
    if ($TenantSetInboxRules.count -gt 0) {
        
        Out-LogFile ("Found " + $TenantSetInboxRules.count + " Inbox Rule(s) created from PowerShell")
        $TenantSetInboxRules | Get-SimpleAdminAuditLog | Out-MultipleFileType -fileprefix "Simple_Set_InboxRule" -csv
        $TenantSetInboxRules | Out-MultipleFileType -fileprefix "Set_InboxRules" -csv
    }

    # Search for the Modification of ANY inbox rules    
    Out-LogFile "Searching for ALL Inbox Rules Removed in the Shell" -action
    [array]$TenantRemoveInboxRules = Search-AdminAuditLog -Cmdlets Remove-InboxRule -StartDate $Hawk.StartDate -EndDate $Hawk.EndDate
            
    # If we found anything report it and log it
    if ($TenantRemoveInboxRules.count -gt 0) {
            
        Out-LogFile ("Found " + $TenantRemoveInboxRules.count + " Inbox Rule(s) created from PowerShell")
        $TenantRemoveInboxRules | Get-SimpleAdminAuditLog | Out-MultipleFileType -fileprefix "Simple_Remove_InboxRule" -csv
        $TenantRemoveInboxRules | Out-MultipleFileType -fileprefix "Remove_InboxRules" -csv
    }
    
    # Searching for interesting inbox rules
    Out-LogFile "Searching for Interesting Inbox Rules Created in the Shell" -action
    [array]$InvestigateInboxRules = Search-AdminAuditLog -StartDate $Hawk.StartDate -EndDate $Hawk.EndDate -cmdlets New-InboxRule -Parameters ForwardTo, ForwardAsAttachmentTo, RedirectTo, DeleteMessage
	
    # if we found a rule report it and output it to the _Investigate files
    if ($InvestigateInboxRules.count -gt 0) {
        Out-LogFile ("Found " + $InvestigateInboxRules.count + " Inbox Rules that should be investigated further.") -notice
        $InvestigateInboxRules | Get-SimpleAdminAuditLog | Out-MultipleFileType -fileprefix "_Investigate_Simple_New_InboxRule" -csv -Notice
        $InvestigateInboxRules | Out-MultipleFileType -fileprefix "_Investigate_New_InboxRules" -xml -txt -Notice
    }
		
    # Look for changes to user forwarding
    Out-LogFile "Searching for user Forwarding Changes" -action
    [array]$TenantForwardingChanges = Search-AdminAuditLog -Cmdlets Set-Mailbox -Parameters ForwardingAddress, ForwardingSMTPAddress -StartDate $Hawk.StartDate -EndDate $Hawk.EndDate
	
    if ($TenantForwardingChanges.count -gt 0) {
        Out-LogFile ("Found " + $TenantForwardingChanges.count + " Change(s) to user Email Forwarding") -notice
        $TenantForwardingChanges | Get-SimpleAdminAuditLog | Out-MultipleFileType -FilePrefix "Simple_Forwarding_Changes" -csv -Notice
        $TenantForwardingChanges | Out-MultipleFileType -FilePrefix "Forwarding_Changes" -xml -Notice
		
        # Make sure our output array is null
        [array]$Output = $null
		
        # Checking if addresses were added or removed
        # If added compile a list
        Foreach ($Change in $TenantForwardingChanges) {

            # Get the user object modified
            $user = ($Change.CmdletParameters | Where-Object ($_.name -eq "Identity")).value

            # Check the ForwardingSMTPAddresses first
            if ([string]::IsNullOrEmpty(($Change.CmdletParameters | Where-Object { $_.name -eq "ForwardingSMTPAddress" }).value)) { }
            # If not null then push the email address into $output
            else {
                [array]$Output = $Output + ($Change.CmdletParameters | Where-Object { $_.name -eq "ForwardingSMTPAddress" }) | Select-Object -Property @{Name = "UserModified"; Expression = { $user } }, @{Name = "TargetSMTPAddress"; Expression = { $_.value.split(":")[1] } }
            }
			
            # Check ForwardingAddress
            if ([string]::IsNullOrEmpty(($Change.CmdletParameters | Where-Object { $_.name -eq "ForwardingAddress" }).value)) { }
            else {
                # Here we get back a recipient object in EXO not an SMTP address
                # So we need to go track down the recipient object
                $recipient = Get-Recipient (($Change.CmdletParameters | Where-Object { $_.name -eq "ForwardingAddress" }).value) -ErrorAction SilentlyContinue
				
                # If we can't resolve the recipient we need to log that
                if ($null -eq $recipient) {
                    Out-LogFile ("Unable to resolve forwarding Target Recipient " + ($Change.CmdletParameters | Where-Object { $_.name -eq "ForwardingAddress" })) -notice
                }
                # If we can resolve it then we need to push the address the mail was being set to into $output
                else {
                    # Determine the type of recipient and handle as needed to get out the SMTP address
                    Switch ($recipient.RecipientType) {
                        # For mailcontact we needed the external email address
                        MailContact {
                            [array]$Output += $recipient | Select-Object -Property @{Name = "UserModified"; Expression = { $user } }; @{Name = "TargetSMTPAddress"; Expression = { $_.ExternalEmailAddress.split(":")[1] } }
                        }
                        # For all others I believe primary will work
                        Default {
                            [array]$Output += $recipient | Select-Object -Property @{Name = "UserModified"; Expression = { $user } }; @{Name = "TargetSMTPAddress"; Expression = { $_.PrimarySmtpAddress } }
                        }
                    }
                }
            }					
        }
		
        # Output our email address user modified pairs
        Out-logfile ("Found " + $Output.count + " email addresses set to be forwarded mail") -notice
        $Output | Out-MultipleFileType -FilePrefix "Forwarding_Recipients" -csv -Notice

    }
    
    # Look for changes to mailbox permissions
    Out-LogFile "Searching for Mailbox Permissions Changes" -Action
    [array]$TenantMailboxPermissionChanges = Search-AdminAuditLog -StartDate $Hawk.StartDate -EndDate $Hawk.EndDate -cmdlets Add-MailboxPermission
	
    if ($TenantMailboxPermissionChanges.count -gt 0) {
        Out-LogFile ("Found " + $TenantMailboxPermissionChanges.count + " changes to mailbox permissions")
        $TenantMailboxPermissionChanges | Get-SimpleAdminAuditLog | Out-MultipleFileType -fileprefix "Simple_Mailbox_Permissions" -csv
        $TenantMailboxPermissionChanges | Out-MultipleFileType -fileprefix "Mailbox_Permissions" -xml

        ## TODO: Possibly check who was added with permissions and see how old their accounts are		
    }

    # Look for change to impersonation access
    Out-LogFile "Searching Impersonation Access" -action
    [array]$TenantImpersonatingRoles = Get-ManagementRoleEntry "*\Impersonate-ExchangeUser"
    if ($TenantImpersonatingRoles.count -gt 1) {
        Out-LogFile ("Found " + $TenantImpersonatingRoles.count + " Impersonation Roles.  Default is 1") -notice
        $TenantImpersonatingRoles | Out-MultipleFileType -fileprefix "_Investigate_Impersonation_Roles" -csv -xml -Notice
    }
    elseif ($TenantImpersonatingRoles.count -eq 0) { }
    else {
        $TenantImpersonatingRoles | Out-MultipleFileType -fileprefix "Impersonation_Roles" -csv -xml
    }
	
    $Output = $null
    # Search all impersonation roles for users that have access
    foreach ($Role in $TenantImpersonatingRoles) {
        [array]$Output += Get-ManagementRoleAssignment -Role $Role.role -GetEffectiveUsers -Delegating:$false
    }
	
    if ($Output.count -gt 1) {
        Out-LogFile ("Found " + $Output.cout + " Users/Groups with Impersonation rights.  Default is 1") -notice
        $Output | Out-MultipleFileType -fileprefix "Impersonation_Rights" -csv -xml
        $Output | Out-MultipleFileType -fileprefix "_Investigate_Impersonation_Rights" -csv -xml -Notice
    }
    elseif ($Output.count -eq 1) {
        Out-LogFile ("Found default number of Impersonation users")
        $Output | Out-MultipleFileType -fileprefix "Impersonation_Rights" -csv -xml
    }
    else { }

}