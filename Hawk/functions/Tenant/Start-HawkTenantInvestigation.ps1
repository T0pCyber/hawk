﻿Function Start-HawkTenantInvestigation {
	<#
.SYNOPSIS
    Gathers common data about a tenant.
.DESCRIPTION
    Runs all Hawk Basic tenant related cmdlets and gathers data about the tenant's configuration,
    security settings, and audit logs. This comprehensive investigation helps identify potential
    security issues and configuration changes.

.PARAMETER Confirm
    Prompts for confirmation before running operations that could modify system state.

.PARAMETER WhatIf
    Shows what would happen if the command runs. The command is not run.

.EXAMPLE
    PS C:\> Start-HawkTenantInvestigation
    Runs a complete tenant investigation, gathering all available data.

.EXAMPLE
    PS C:\> Start-HawkTenantInvestigation -WhatIf
    Shows what data gathering operations would be performed without executing them.

.EXAMPLE
    PS C:\> Start-HawkTenantInvestigation -Confirm
    Prompts for confirmation before running each data gathering operation.

.OUTPUTS
    Various CSV, JSON, and XML files containing investigation results.
    See help from individual cmdlets for specific output details.
    All outputs are placed in the $Hawk.FilePath directory.
#>
	[CmdletBinding(SupportsShouldProcess)]
	param()

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
		Out-LogFile "Running Get-HawkTenantConsentGrant" -action
		Get-HawkTenantConsentGrant
	}

	if ($PSCmdlet.ShouldProcess("Azure Admins", "Get Azure admin list")) {
		Out-LogFile "Running Get-HawkTenantAZAdmin" -action
		Get-HawkTenantAZAdmin
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