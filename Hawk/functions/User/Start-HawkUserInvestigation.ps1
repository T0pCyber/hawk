Function Start-HawkUserInvestigation {
    <#
    .SYNOPSIS
        Performs a comprehensive user-specific investigation using Hawk's automated data collection capabilities.

    .DESCRIPTION
        Start-HawkUserInvestigation automates the collection and analysis of Microsoft 365 security data
        for specific users. It runs multiple specialized cmdlets to gather detailed information about user
        configuration, activities, and potential security concerns.

        The command can run in either interactive mode (default) or non-interactive mode. Interactive mode is used
        when only UserPrincipalName is provided, while non-interactive mode is automatically enabled when any
        additional parameter is specified.

        Data collected includes:
        - User mailbox configuration and statistics
        - Inbox rules and email forwarding settings
        - Authentication history and mailbox audit logs
        - Administrative changes affecting the user
        - Message trace data and mobile device access
        - AutoReply configuration
        
        All collected data is stored in a structured format for analysis, with suspicious findings
        highlighted for investigation.

    .PARAMETER UserPrincipalName
        Single UPN of a user, comma-separated list of UPNs, or an array of objects that contain UPNs.
        This is the only required parameter and specifies which users to investigate.

    .PARAMETER StartDate
        The beginning date for the investigation period. When specified, must be used with EndDate.
        Cannot be later than EndDate and the date range cannot exceed 365 days.
        Providing this parameter automatically enables non-interactive mode.
        Format: MM/DD/YYYY

    .PARAMETER EndDate
        The ending date for the investigation period. When specified, must be used with StartDate.
        Cannot be in the future and the date range cannot exceed 365 days.
        Providing this parameter automatically enables non-interactive mode.
        Format: MM/DD/YYYY

    .PARAMETER DaysToLookBack
        Alternative to StartDate/EndDate. Specifies the number of days to look back from the current date.
        Must be between 1 and 365. Cannot be used together with StartDate.
        Providing this parameter automatically enables non-interactive mode.

    .PARAMETER FilePath
        The file system path where investigation results will be stored.
        Required in non-interactive mode. Must be a valid file system path.
        Providing this parameter automatically enables non-interactive mode.

    .PARAMETER SkipUpdate
        Switch to bypass the automatic check for Hawk module updates.
        Useful in automated scenarios or air-gapped environments.
        Providing this parameter automatically enables non-interactive mode.

    .PARAMETER Confirm
        Prompts you for confirmation before executing each investigation step.
        By default, confirmation prompts appear for operations that could collect sensitive data.

    .PARAMETER WhatIf
        Shows what would happen if the command runs. The command is not executed.
        Use this parameter to understand which investigation steps would be performed without actually collecting data.

    .OUTPUTS
        Creates multiple CSV and JSON files containing investigation results.
        All outputs are organized in user-specific folders under the specified FilePath directory.
        See individual cmdlet help for specific output details.

    .EXAMPLE
        Start-HawkUserInvestigation -UserPrincipalName user@contoso.com

        Investigates a single user in interactive mode, prompting for date range and output location.

    .EXAMPLE
        Start-HawkUserInvestigation -UserPrincipalName user@contoso.com -DaysToLookBack 30 -FilePath "C:\Investigation"

        Investigates a single user looking back 30 days, saving results to C:\Investigation.
        Runs in non-interactive mode because parameters beyond UserPrincipalName were specified.

    .EXAMPLE
        Start-HawkUserInvestigation `
            -UserPrincipalName (Get-Mailbox -Filter {CustomAttribute1 -eq "C-level"}) `
            -StartDate "01/01/2024" `
            -EndDate "01/31/2024" `
            -FilePath "C:\Investigation"

        Investigates all users with CustomAttribute1="C-level" for January 2024.
        Runs in non-interactive mode because multiple parameters were specified.
    .LINK
        https://cloudforensicator.com

    .LINK
        https://github.com/T0pCyber/hawk
    #>
	[CmdletBinding(SupportsShouldProcess = $true)]
	param (
		[Parameter(Mandatory = $true)]
		[array]$UserPrincipalName,

		[DateTime]$StartDate,
		[DateTime]$EndDate,
		[int]$DaysToLookBack,
		[string]$FilePath,
		[switch]$SkipUpdate
	)

	begin {
        $NonInteractive = Test-HawkNonInteractiveMode -PSBoundParameters $PSBoundParameters

		if ($NonInteractive) {
			$processedDates = Test-HawkDateParameter -PSBoundParameters $PSBoundParameters -StartDate $StartDate -EndDate $EndDate -DaysToLookBack $DaysToLookBack
			$StartDate = $processedDates.StartDate
			$EndDate = $processedDates.EndDate
	
			# Now call validation with updated StartDate/EndDate
			$validation = Test-HawkInvestigationParameter `
				-StartDate $StartDate -EndDate $EndDate `
				-DaysToLookBack $DaysToLookBack -FilePath $FilePath -NonInteractive
	
			if (-not $validation.IsValid) {
				foreach ($error in $validation.ErrorMessages) {
					Stop-PSFFunction -Message $error -EnableException $true
				}
			}

			try {
				Initialize-HawkGlobalObject -StartDate $StartDate -EndDate $EndDate `
					-DaysToLookBack $DaysToLookBack -FilePath $FilePath `
					-SkipUpdate:$SkipUpdate -NonInteractive:$NonInteractive
			}
			catch {
				Stop-PSFFunction -Message "Failed to initialize Hawk: $_" -EnableException $true
			}
		}
	}

	process {
		if (Test-PSFFunctionInterrupt) { return }

		# Check if Hawk object exists and is fully initialized
		if (Test-HawkGlobalObject) {
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
	
				# if ($PSCmdlet.ShouldProcess("Running Get-HawkUserConfiguration for $User")) {
				# 	Out-LogFile "Running Get-HawkUserConfiguration" -Action
				# 	Get-HawkUserConfiguration -User $User
				# }
	
				# if ($PSCmdlet.ShouldProcess("Running Get-HawkUserInboxRule for $User")) {
				# 	Out-LogFile "Running Get-HawkUserInboxRule" -Action
				# 	Get-HawkUserInboxRule -User $User
				# }
	
				# if ($PSCmdlet.ShouldProcess("Running Get-HawkUserEmailForwarding for $User")) {
				# 	Out-LogFile "Running Get-HawkUserEmailForwarding" -Action
				# 	Get-HawkUserEmailForwarding -User $User
				# }
	
				# if ($PSCmdlet.ShouldProcess("Running Get-HawkUserAutoReply for $User")) {
				# 	Out-LogFile "Running Get-HawkUserAutoReply" -Action
				# 	Get-HawkUserAutoReply -User $User
				# }
	
				# if ($PSCmdlet.ShouldProcess("Running Get-HawkUserAuthHistory for $User")) {
				# 	Out-LogFile "Running Get-HawkUserAuthHistory" -Action
				# 	Get-HawkUserAuthHistory -User $User -ResolveIPLocations
				# }
	
				# if ($PSCmdlet.ShouldProcess("Running Get-HawkUserMailboxAuditing for $User")) {
				# 	Out-LogFile "Running Get-HawkUserMailboxAuditing" -Action
				# 	Get-HawkUserMailboxAuditing -User $User
				# }
	
				# if ($PSCmdlet.ShouldProcess("Running Get-HawkUserAdminAudit for $User")) {
				# 	Out-LogFile "Running Get-HawkUserAdminAudit" -Action
				# 	Get-HawkUserAdminAudit -User $User
				# }
	
				# if ($PSCmdlet.ShouldProcess("Running Get-HawkUserMessageTrace for $User")) {
				# 	Out-LogFile "Running Get-HawkUserMessageTrace" -Action
				# 	Get-HawkUserMessageTrace -User $User
				# }

				# if ($PSCmdlet.ShouldProcess("Running Get-HawkUserMailItemsAccessed for $User")) {
				# 	Out-LogFile "Running Get-HawkUserMailItemsAccessed" -Action
				# 	Get-HawkUserMailItemsAccessed -UserPrincipalName $User
				# }
	
				# if ($PSCmdlet.ShouldProcess("Running Get-HawkUserMobileDevice for $User")) {
				# 	Out-LogFile "Running Get-HawkUserMobileDevice" -Action
				# 	Get-HawkUserMobileDevice -User $User
				# }

				if ($PSCmdlet.ShouldProcess("Running Get-HawkUserSharePointSearchQuery for $User")) {
					Out-LogFile "Running Get-HawkUserSharePointSearchQuery" -Action
					Get-HawkUserSharePointSearchQuery -UserPrincipalName $User
				}
			}
		}

	}

}
	