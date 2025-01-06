Function Start-HawkUserInvestigation {
	<#
	.SYNOPSIS
		Gathers common data about a provided user.
	
	.DESCRIPTION
		Runs all Hawk user-related cmdlets against the specified user and gathers the data.
	
		Cmdlet                              Information Gathered
		-------------------------           -------------------------
		Get-HawkTenantConfiguration         Basic Tenant information
		Get-HawkUserConfiguration           Basic User information
		Get-HawkUserInboxRule               Searches the user for Inbox Rules
		Get-HawkUserEmailForwarding         Looks for email forwarding configured on the user
		Get-HawkUserAutoReply               Looks for enabled AutoReplyConfiguration
		Get-HawkUserAuthHistory             Searches the unified audit log for user logons
		Get-HawkUserMailboxAuditing         Searches the unified audit log for mailbox auditing information
		Get-HawkUserAdminAudit              Searches the EXO Audit logs for commands run against the provided user
		Get-HawkUserMessageTrace            Pulls emails sent by the user in the last 7 days
	
	.PARAMETER UserPrincipalName
		Single UPN of a user, comma-separated list of UPNs, or an array of objects that contain UPNs.
	
	.PARAMETER Confirm
		Prompts for confirmation before running operations that could modify system state.
	
	.PARAMETER WhatIf
		Shows what would happen if the command runs. The command is not actually run.
	
	.OUTPUTS
		See help from individual cmdlets for output list.
		All outputs are placed in the $Hawk.FilePath directory.
	
	.EXAMPLE
		Start-HawkUserInvestigation -UserPrincipalName bsmith@contoso.com
	
		Runs all Get-HawkUser* cmdlets against the user with UPN bsmith@contoso.com.
	
	.EXAMPLE
		Start-HawkUserInvestigation -UserPrincipalName (Get-Mailbox -Filter {CustomAttribute1 -eq "C-level"})
	
		Runs all Get-HawkUser* cmdlets against all users who have "C-Level" set in CustomAttribute1.
	
	.NOTES
		Ensure the Hawk global object is initialized with a valid logging file path before running this function.
	#>
		[CmdletBinding(SupportsShouldProcess = $true)]
		param (
			[Parameter(Mandatory = $true)]
			[array]$UserPrincipalName
		)
	
		# Check if the logging filepath is set
		if ([string]::IsNullOrEmpty($Hawk.FilePath)) {
			Initialize-HawkGlobalObject
		}
	
		if ($PSCmdlet.ShouldProcess("Investigating Users")) {
			Out-LogFile "Investigating Users" -Action
			Send-AIEvent -Event "CmdRun"
	
			# Pull the tenant configuration
			Get-HawkTenantConfiguration
	
			# Verify the UPN input
			[array]$UserArray = Test-UserObject -ToTest $UserPrincipalName
	
			foreach ($Object in $UserArray) {
				[string]$User = $Object.UserPrincipalName
	
				if ($PSCmdlet.ShouldProcess("Running Get-HawkUserConfiguration for $User")) {
					Out-LogFile "Running Get-HawkUserConfiguration" -Action
					Get-HawkUserConfiguration -User $User
				}
	
				if ($PSCmdlet.ShouldProcess("Running Get-HawkUserInboxRule for $User")) {
					Out-LogFile "Running Get-HawkUserInboxRule" -Action
					Get-HawkUserInboxRule -User $User
				}
	
				if ($PSCmdlet.ShouldProcess("Running Get-HawkUserEmailForwarding for $User")) {
					Out-LogFile "Running Get-HawkUserEmailForwarding" -Action
					Get-HawkUserEmailForwarding -User $User
				}
	
				if ($PSCmdlet.ShouldProcess("Running Get-HawkUserAutoReply for $User")) {
					Out-LogFile "Running Get-HawkUserAutoReply" -Action
					Get-HawkUserAutoReply -User $User
				}
	
				if ($PSCmdlet.ShouldProcess("Running Get-HawkUserAuthHistory for $User")) {
					Out-LogFile "Running Get-HawkUserAuthHistory" -Action
					Get-HawkUserAuthHistory -User $User -ResolveIPLocations
				}
	
				if ($PSCmdlet.ShouldProcess("Running Get-HawkUserMailboxAuditing for $User")) {
					Out-LogFile "Running Get-HawkUserMailboxAuditing" -Action
					Get-HawkUserMailboxAuditing -User $User
				}
	
				if ($PSCmdlet.ShouldProcess("Running Get-HawkUserAdminAudit for $User")) {
					Out-LogFile "Running Get-HawkUserAdminAudit" -Action
					Get-HawkUserAdminAudit -User $User
				}
	
				if ($PSCmdlet.ShouldProcess("Running Get-HawkUserMessageTrace for $User")) {
					Out-LogFile "Running Get-HawkUserMessageTrace" -Action
					Get-HawkUserMessageTrace -User $User
				}
	
				if ($PSCmdlet.ShouldProcess("Running Get-HawkUserMobileDevice for $User")) {
					Out-LogFile "Running Get-HawkUserMobileDevice" -Action
					Get-HawkUserMobileDevice -User $User
				}
			}
		}
	}
	