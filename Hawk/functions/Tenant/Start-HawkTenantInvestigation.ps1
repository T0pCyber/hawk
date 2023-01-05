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

R	uns all of the tenant investigation cmdlets.
#>
	if ([string]::IsNullOrEmpty($Hawk.FilePath)) {
		Initialize-HawkGlobalObject
	}

	Out-LogFile "Starting Tenant Sweep" -action
	Send-AIEvent -Event "CmdRun"

	Out-LogFile "Running Get-HawkTenantConfiguration" -action
	Get-HawkTenantConfiguration

	Out-LogFile "Running Get-HawkTenantEDiscoveryConfiguration" -action
	Get-HawkTenantEDiscoveryConfiguration

	Out-LogFile "Running Get-HawkTenantEXOAuditLog" -action
	Search-HawkTenantEXOAuditLog

	Out-LogFile "Running Get-HawkTenantRBACChanges" -action
	Get-HawkTenantRBACChanges

	Out-LogFile "Running Get-HawkTenantAzureAppAuditLog" -action
	Get-HawkTenantAzureAppAuditLog

	Out-LogFile "Running Get-HawkTenantEXOAdmins" -action
	Get-HawkTenantEXOAdmins

	Out-LogFile "Running Get-HawkTenantConsentGrants" -action
	Get-HawkTenantConsentGrants

	Out-LogFile "Running Get-HawkTenantAZAdmins" -action
	Get-HawkTenantAZAdmins

	Out-LogFile "Running Get-HawkTenantAppAndSPNCredentialDetails" -action
	Get-HawkTenantAppAndSPNCredentialDetails

	Out-Logfile "Running Get-HawkTenantAzureADUsers" -action
	Get-HawkTenantAzureADUsers
}