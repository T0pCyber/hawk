# Executes the series of Hawk cmdets that search the whole tenant
Function Start-HawkTenantInvestigation {

	Out-LogFile "Starting Tenant Sweep"
	Send-AIEvent -Event "CmdRun"
	
	Out-Log "Running Get-HawkTenantConfiguration" -action
	Get-HawkTenantConfiguration

	Out-Log "Running Get-HawkTenantEDiscoveryConfiguration" -action
	Get-HawkTenantEDiscoveryConfiguration
	
	Out-Log "Running Get-HawkTenantEXOAuditLog" -action
	Search-HawkTenantEXOAuditLog
	
	Out-Log "Running Get-HawkTenantRBACChanges" -action
    Get-HawkTenantRBACChanges

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
}