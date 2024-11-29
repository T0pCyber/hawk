Function Start-HawkTenantInvestigation {
	[CmdletBinding(SupportsShouldProcess)]
	param()
    
	<#
    .SYNOPSIS
        Gathers common data about a tenant.
    .DESCRIPTION
        Runs all Hawk Basic tenant related cmdlets and gathers the data.

        Cmdlet                                  Information Gathered
        -------------------------               -------------------------
        Get-HawkTenantConfigurationn           Basic Tenant information
        Get-HawkTenantEDiscoveryConfiguration  Looks for changes to ediscovery configuration
        Search-HawkTenantEXOAuditLog          Searches the EXO audit log for activity
        Get-HawkTenantRBACChanges             Looks for changes to Roles Based Access Control
    .OUTPUTS
        See help from individual cmdlets for output list.
        All outputs are placed in the $Hawk.FilePath directory
    .EXAMPLE
        Start-HawkTenantInvestigation

        Runs all of the tenant investigation cmdlets.
    .EXAMPLE
        Start-HawkTenantInvestigation -WhatIf

        Shows what actions would be performed without actually executing them.
    #>

	if ([string]::IsNullOrEmpty($Hawk.FilePath)) {
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

	if ($PSCmdlet.ShouldProcess("Exchange Audit Log", "Search audit logs")) {
		Out-LogFile "Running Search-HawkTenantEXOAuditLog" -action
		Search-HawkTenantEXOAuditLog
	}

	if ($PSCmdlet.ShouldProcess("EDiscovery Logs", "Get eDiscovery logs")) {
		Out-LogFile "Running Get-HawkTenantEDiscoveryLogs" -action
		Get-HawkTenantEDiscoveryLogs
	}

	if ($PSCmdlet.ShouldProcess("Domain Activity", "Get domain activity")) {
		Out-LogFile "Running Get-HawkTenantDomainActivity" -action
		Get-HawkTenantDomainActivity
	}

	if ($PSCmdlet.ShouldProcess("RBAC Changes", "Get RBAC changes")) {
		Out-LogFile "Running Get-HawkTenantRBACChanges" -action
		Get-HawkTenantRBACChanges
	}

	if ($PSCmdlet.ShouldProcess("Azure App Audit Log", "Get app audit logs")) {
		Out-LogFile "Running Get-HawkTenantAzureAppAuditLog" -action
		Get-HawkTenantAzureAppAuditLog
	}

	if ($PSCmdlet.ShouldProcess("Exchange Admins", "Get Exchange admin list")) {
		Out-LogFile "Running Get-HawkTenantEXOAdmins" -action
		Get-HawkTenantEXOAdmins
	}

	if ($PSCmdlet.ShouldProcess("Consent Grants", "Get consent grants")) {
		Out-LogFile "Running Get-HawkTenantConsentGrants" -action
		Get-HawkTenantConsentGrants
	}

	if ($PSCmdlet.ShouldProcess("Azure Admins", "Get Azure admin list")) {
		Out-LogFile "Running Get-HawkTenantAZAdmins" -action
		Get-HawkTenantAZAdmins
	}

	if ($PSCmdlet.ShouldProcess("App and SPN Credentials", "Get credential details")) {
		Out-LogFile "Running Get-HawkTenantAppAndSPNCredentialDetails" -action
		Get-HawkTenantAppAndSPNCredentialDetails
	}

	if ($PSCmdlet.ShouldProcess("Azure AD Users", "Get Azure AD user list")) {
		Out-LogFile "Running Get-HawkTenantAzureADUsers" -action
		Get-HawkTenantAzureADUsers
	}
}