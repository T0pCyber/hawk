Function Start-HawkTenantInvestigation {
    <#
    .SYNOPSIS
        Performs a comprehensive tenant-wide investigation using Hawk's automated data collection capabilities.

    .DESCRIPTION
        Start-HawkTenantInvestigation automates the collection and analysis of Microsoft 365 tenant-wide security data.
        It gathers information about tenant configuration, security settings, administrative changes, and potential security
        issues across the environment.

        The command can run in either interactive mode (default) or non-interactive mode. Interactive mode is used
        when no parameters are provided, while non-interactive mode is automatically enabled when any parameter is
        specified. In interactive mode, it prompts for necessary information such as date ranges and output location.

        Data collected includes:
        - Tenant configuration settings
        - eDiscovery configuration and logs
        - Administrative changes and permissions
        - Domain activities
        - Application consents and credentials
        - Exchange Online administrative activities

        All collected data is stored in a structured format for analysis, with suspicious findings highlighted
        for investigation.

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
        All outputs are placed in the specified FilePath directory.
        See individual cmdlet help for specific output details.

    .EXAMPLE
        Start-HawkTenantInvestigation

        Runs a tenant investigation in interactive mode, prompting for date range and output location.

    .EXAMPLE
        Start-HawkTenantInvestigation -DaysToLookBack 30 -FilePath "C:\Investigation"

        Performs a tenant investigation looking back 30 days from today, saving results to C:\Investigation.
        Runs in non-interactive mode because parameters were specified.

    .EXAMPLE
        Start-HawkTenantInvestigation -StartDate "01/01/2024" -EndDate "01/31/2024" -FilePath "C:\Investigation" -SkipUpdate

        Investigates tenant activity for January 2024, saving results to C:\Investigation.
        Skips the update check. Runs in non-interactive mode because parameters were specified.

    .EXAMPLE
        Start-HawkTenantInvestigation -WhatIf

        Shows what investigation steps would be performed without actually executing them.
        Useful for understanding the investigation process or validating parameters.

    .LINK
        https://hawkforensics.io

    .LINK
        https://github.com/T0pCyber/hawk
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
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
        $investigationStartTime = Get-Date
        Out-LogFile "Starting Tenant Investigation" -action
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

        if ($PSCmdlet.ShouldProcess("EDiscovery Logs", "Get eDiscovery logs")) {
        	Out-LogFile "Running Get-HawkTenantEDiscoveryLog" -action
        	Get-HawkTenantEDiscoveryLog
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
			
        if ($PSCmdlet.ShouldProcess("Domain Activity", "Get domain activity")) {
        	Out-LogFile "Running Get-HawkTenantDomainActivity" -action
        	Get-HawkTenantDomainActivity
        }
	
        if ($PSCmdlet.ShouldProcess("RBAC Changes", "Get RBAC changes")) {
        	Out-LogFile "Running Get-HawkTenantRBACChange" -action
        	Get-HawkTenantRBACChange
        }

        if ($PSCmdlet.ShouldProcess("Entra ID Audit Log", "Get Entra ID audit logs")) {
        	Out-LogFile "Running Get-HawkTenantEntraIDAuditLog" -action
        	Get-HawkTenantEntraIDAuditLog
        }
	
        if ($PSCmdlet.ShouldProcess("Entra ID App Audit Log", "Get Entra ID app audit logs")) {
        	Out-LogFile "Running Get-HawkTenantEntraIDAppAuditLog" -action
        	Get-HawkTenantEntraIDAppAuditLog
        }
	
        if ($PSCmdlet.ShouldProcess("Exchange Admins", "Get Exchange admin list")) {
        	Out-LogFile "Running Get-HawkTenantEXOAdmin" -action
        	Get-HawkTenantEXOAdmin
        }
	
        if ($PSCmdlet.ShouldProcess("Consent Grants", "Get consent grants")) {
            Out-LogFile "Running Get-HawkTenantConsentGrant" -action
            Get-HawkTenantConsentGrant
        }

        if ($PSCmdlet.ShouldProcess("Risky Users", "Get Entra ID Risky Users")) {
            Out-LogFile "Running Get-HawkTenantRiskyUsers" -action
            Get-HawkTenantRiskyUsers
        }

        if ($PSCmdlet.ShouldProcess("Risk Detections", "Get Entra ID Risk Detections")) {
        	Out-LogFile "Running Get-HawkTenantRiskDetections" -action
        	Get-HawkTenantRiskDetections
        }

        ####################################################################################
        #TODO: If DCODev's test of Get-RiskyServicePrincipals is good, add a call to it here
        ####################################################################################
	
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
    end {
        # Calculate end time and display summary
        $investigationEndTime = Get-Date
        Write-HawkInvestigationSummary -StartTime $investigationStartTime -EndTime $investigationEndTime -InvestigationType 'Tenant'
    }

 
}