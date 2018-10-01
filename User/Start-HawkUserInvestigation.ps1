# String together the hawk user functions to pull data for a single user
Function Start-HawkUserInvestigation {
    param
    (
        [Parameter(Mandatory = $true)]
        [array]$UserPrincipalName
    )

    Get-HawkTenantConfiguration

    # Verify our UPN input
    [array]$UserArray = Test-UserObject -ToTest $UserPrincipalName

    foreach ($Object in $UserArray) {
        [string]$User = $Object.UserPrincipalName
		
        Get-HawkUserConfiguration -User $User
        Get-HawkUserInboxRule -User $User
        Get-HawkUserEmailForwarding -User $User
        Get-HawkUserAuthHistory -User $user -ResolveIPLocations
		Get-HawkUserMailboxAuditing -User $User
		Get-HawkUserAdminAudit -User $User
    }

    <#
 
	.SYNOPSIS
	Gathers common data about a provided user.

	.DESCRIPTION
	Runs all Hawk users related cmdlets against the specified user and gathers the data.

	Cmdlet								Information Gathered
	-------------------------			-------------------------
	Get-HawkTenantConfigurationn        Basic Tenant information
	Get-HawkUserConfiguration           Basic User information
	Get-HawkUserInboxRule               Searches the user for Inbox Rules
	Get-HawkUserEmailForwarding         Looks for email forwarding configured on the user
	Get-HawkuserAuthHistory             Searches the unified audit log for users logons
	Get-HawkUserMailboxAuditing         Searches the unified audit log for mailbox auditing information
	Get-HawkUserAdminAudit					

	.PARAMETER UserPrincipalName
	Single UPN of a user, commans seperated list of UPNs, or array of objects that contain UPNs.

	.OUTPUTS
	See help from individual cmdlets for output list.
	All outputs are placed in the $Hawk.FilePath directory

	.EXAMPLE
	Start-HawkUserInvestigation -UserPrincipalName bsmith@contoso.com

	Runs all Get-HawkUser* cmdlets against the user with UPN bsmith@contoso.com

	.EXAMPLE

	Start-HawkUserInvestigation -UserPrincipalName (get-mailbox -Filter {Customattribute1 -eq "C-level"})

	Runs all Get-HawkUser* cmdlets against all users who have "C-Level" set in CustomAttribute1
	
	#>

}