Function Start-HawkTenantInvestigation {
    <#
    .SYNOPSIS
        Validates parameters for Hawk investigation commands in both interactive and non-interactive modes.

    .DESCRIPTION
        The Test-HawkInvestigationParameters function performs comprehensive validation of parameters used in Hawk's investigation commands. 
        It ensures that all required parameters are present and valid when running in non-interactive mode, while also validating date ranges 
        and other constraints that apply in both modes.

        The function validates:
        - File path existence and validity
        - Presence of required date parameters in non-interactive mode
        - Date range constraints (max 365 days, start before end)
        - DaysToLookBack value constraints (1-365 days)
        - Future date restrictions
        
        When validation fails, the function returns detailed error messages explaining which validations failed and why.
        These messages can be used to provide clear guidance to users about how to correct their parameter usage.

    .PARAMETER StartDate
        The beginning date for the investigation period. Must be provided with EndDate in non-interactive mode.
        Cannot be later than EndDate or result in a date range exceeding 365 days.

    .PARAMETER EndDate
        The ending date for the investigation period. Must be provided with StartDate in non-interactive mode.
        Cannot be in the future or result in a date range exceeding 365 days.

    .PARAMETER DaysToLookBack
        Alternative to StartDate/EndDate. Specifies the number of days to look back from the current date.
        Must be between 1 and 365. Cannot be used together with StartDate/EndDate parameters.

    .PARAMETER FilePath
        The file system path where investigation results will be stored.
        Must be a valid file system path. Required in non-interactive mode.

    .PARAMETER NonInteractive
        Switch that indicates whether Hawk is running in non-interactive mode.
        When true, enforces stricter parameter validation requirements.

    .OUTPUTS
        PSCustomObject with two properties:
        - IsValid (bool): Indicates whether all validations passed
        - ErrorMessages (string[]): Array of error messages when validation fails

    .EXAMPLE
        $validation = Test-HawkInvestigationParameters -StartDate "2024-01-01" -EndDate "2024-01-31" -FilePath "C:\Investigation" -NonInteractive
        
        Validates parameters for investigating January 2024 in non-interactive mode.

    .EXAMPLE
        $validation = Test-HawkInvestigationParameters -DaysToLookBack 30 -FilePath "C:\Investigation" -NonInteractive
        
        Validates parameters for a 30-day lookback investigation in non-interactive mode.

    .NOTES
        This is an internal function used by Start-HawkTenantInvestigation and Start-HawkUserInvestigation.
        It is not intended to be called directly by users of the Hawk module.
        
        All datetime operations use UTC internally for consistency.
    #>
	[CmdletBinding(SupportsShouldProcess)]
    param (
        [DateTime]$StartDate,
        [DateTime]$EndDate,
        [ValidateRange(1, 365)]
        [int]$DaysToLookBack,
        [string]$FilePath,
        [switch]$SkipUpdate,
        [switch]$NonInteractive
    )

	
    begin {
        # Validate parameters if in non-interactive mode
        if ($NonInteractive) {
            $validation = Test-HawkInvestigationParameters -StartDate $StartDate -EndDate $EndDate `
                -DaysToLookBack $DaysToLookBack -FilePath $FilePath -NonInteractive

            if (-not $validation.IsValid) {
                foreach ($error in $validation.ErrorMessages) {
                    Stop-PSFFunction -Message $error -EnableException $true
                }
            }
        }

        try {
            # Initialize with provided parameters
            Initialize-HawkGlobalObject -StartDate $StartDate -EndDate $EndDate -DaysToLookBack $DaysToLookBack `
                -FilePath $FilePath -SkipUpdate:$SkipUpdate -NonInteractive:$NonInteractive
        }
        catch {
            Stop-PSFFunction -Message "Failed to initialize Hawk: $_" -EnableException $true
        }
    }
    
	process {

        if (Test-PSFFunctionInterrupt) { return }

		# Check if Hawk object exists and is fully initialized
		if (Test-HawkGlobalObject) {
			Initialize-HawkGlobalObject
		}
	
		Out-LogFile "Starting Tenant Sweep" -action
		Send-AIEvent -Event "CmdRun"
	
		# Wrap operations in ShouldProcess checks
		if ($PSCmdlet.ShouldProcess("Tenant Configuration", "Get configuration data")) {
			Out-LogFile "Running Get-HawkTenantConfiguration" -action
			Get-HawkTenantConfiguration
		}
	
		if ($PSCmdlet.ShouldProcess("EDiscovery Configuration", "Get eDiscovery configuration")) {
			Out-LogFile "Running Get-HawkTenantEDiscoveryConfiguration" -action
			Get-HawkTenantEDiscoveryConfiguration
		}
	
		if ($PSCmdlet.ShouldProcess("Admin Inbox Rule Creation Audit Log", "Search Admin Inbox Rule Creation")) {
			Out-LogFile "Running Get-HawkTenantAdminInboxRuleCreation" -action
			Get-HawkTenantAdminInboxRuleCreation
		}
	
		if ($PSCmdlet.ShouldProcess("Admin Inbox Rule Modification Audit Log", "Search Admin Inbox Rule Modification")) {
			Out-LogFile "Running Get-HawkTenantInboxRuleModification" -action
			Get-HawkTenantAdminInboxRuleModification
		}
	
		if ($PSCmdlet.ShouldProcess("Admin Inbox Rule Removal Audit Log", "Search Admin Inbox Rule Removal")) {
			Out-LogFile "Running Get-HawkTenantAdminInboxRuleRemoval" -action
			Get-HawkTenantAdminInboxRuleRemoval
		}
	
		if ($PSCmdlet.ShouldProcess("Admin Inbox Rule Permission Change Audit Log", "Search Admin Inbox Permission Changes")) {
			Out-LogFile "Running Get-HawkTenantAdminMailboxPermissionChange" -action
			Get-HawkTenantAdminMailboxPermissionChange
		}
		
		if ($PSCmdlet.ShouldProcess("Admin Email Forwarding Change Change Audit Log", "Search Admin Email Forwarding Changes")) {
			Out-LogFile "Running Get-HawkTenantAdminEmailForwardingChange" -action
			Get-HawkTenantAdminEmailForwardingChange
		}
	
	
		if ($PSCmdlet.ShouldProcess("EDiscovery Logs", "Get eDiscovery logs")) {
			Out-LogFile "Running Get-HawkTenantEDiscoveryLog" -action
			Get-HawkTenantEDiscoveryLog
		}
	
		if ($PSCmdlet.ShouldProcess("Domain Activity", "Get domain activity")) {
			Out-LogFile "Running Get-HawkTenantDomainActivity" -action
			Get-HawkTenantDomainActivity
		}
	
		if ($PSCmdlet.ShouldProcess("RBAC Changes", "Get RBAC changes")) {
			Out-LogFile "Running Get-HawkTenantRBACChange" -action
			Get-HawkTenantRBACChange
		}
	
		if ($PSCmdlet.ShouldProcess("Azure App Audit Log", "Get app audit logs")) {
			Out-LogFile "Running Get-HawkTenantAzureAppAuditLog" -action
			Get-HawkTenantAzureAppAuditLog
		}
	
		if ($PSCmdlet.ShouldProcess("Exchange Admins", "Get Exchange admin list")) {
			Out-LogFile "Running Get-HawkTenantEXOAdmin" -action
			Get-HawkTenantEXOAdmin
		}
	
		if ($PSCmdlet.ShouldProcess("Consent Grants", "Get consent grants")) {
			Out-LogFile "Running Get-HawkTenantConsentGrant" -action
			Get-HawkTenantConsentGrant
		}
	
		if ($PSCmdlet.ShouldProcess("Entra ID Admins", "Get Entra ID admin list")) {
			Out-LogFile "Running Get-HawkTenantEntraIDAdmin" -action
			Get-HawkTenantEntraIDAdmin
		}
	
		if ($PSCmdlet.ShouldProcess("App and SPN Credentials", "Get credential details")) {
			Out-LogFile "Running Get-HawkTenantAppAndSPNCredentialDetail" -action
			Get-HawkTenantAppAndSPNCredentialDetail
		}
	
		if ($PSCmdlet.ShouldProcess("Entra ID Users", "Get Entra ID user list")) {
			Out-LogFile "Running Get-HawkTenantEntraIDUser" -action
			Get-HawkTenantEntraIDUser
		}

	}

 
}