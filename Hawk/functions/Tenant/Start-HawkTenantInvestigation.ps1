

# Executes the series of Hawk cmdets that search the whole tenant
Function Start-HawkTenantInvestigation {

	<#

	.SYNOPSIS
	Gathers common data about a tenant.

	.DESCRIPTION
	Runs all Hawk Basic tenant related cmdlets and gathers the data.

	Cmdlet									Information Gathered
	-------------------------				-------------------------
	Get-HawkTenantConfigurationn			Basic Tenant information
	Get-HawkTenantEDiscoveryConfiguration	Looks for changes to ediscovery configuration
	Search-HawkTenantEXOAuditLog			Searches the EXO audit log for activity
	Get-HawkTenantRBACChanges				Looks for changes to Roles Based Access Control

	.OUTPUTS
	See help from individual cmdlets for output list.
	All outputs are placed in the $Hawk.FilePath directory

	.EXAMPLE
	Start-HawkTenantInvestigation

	Runs all of the tenant investigation cmdlets.

	#>

	Out-LogFile "Starting Tenant Sweep"
	Send-AIEvent -Event "CmdRun"

	Out-LogFile "Running Get-HawkTenantConfiguration" -action
	Get-HawkTenantConfiguration

	Out-LogFile "Running Get-HawkTenantEDiscoveryConfiguration" -action
	Get-HawkTenantEDiscoveryConfiguration

	Out-LogFile "Running Get-HawkTenantEXOAuditLog" -action
	Search-HawkTenantEXOAuditLog

	Out-LogFile "Running Get-HawkTenantRBACChanges" -action
	Get-HawkTenantRBACChanges

	Out-LogFile "Running Get-HawkTenantAzureAuditLog" -action
	Get-HawkTenantAzureAuditLog

	Out-LogFile "Running Get-HawkTenantConsentGrants" -action
	Get-HawkTenantConsentGrants

	Out-LogFile "Running Get-HawkTenantAZAdmins" -action
	Get-HawkTenantAZAdmins

	Out-LogFile "Running Get-HawkTenantEXOAdmins" -action
	Get-HawkTenantEXOAdmins

	Out-LogFile "Running Get-HawkTenantAppAndSPNCredentialDetails" -action
	Get-HawkTenantAppAndSPNCredentialDetails
}