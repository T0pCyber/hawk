# Search for any changes made to RBAC in the search window and report them
Function Get-HawkTenantRBACChanges {
	
	<#
 
	.SYNOPSIS
	Looks for any changes made to Roles Based Access Control

	.DESCRIPTION
	Searches the EXO Audit logs for the following commands being run.
	New-ManagementRole
	Remove-ManagementRole
	New-ManagementRoleAssignment
	Remove-ManagementRoleAssignment
	Set-MangementRoleAssignment
	New-ManagementScope
	Remove-ManagementScope
	Set-ManagementScope	
		
	.OUTPUTS

	File: Simple_RBAC_Changes.csv
	Path: \
	Description: All RBAC cmdlets that were run in an easy to read format

	File: RBAC_Changes.csv
	Path: \
	Description: All RBAC changes in Raw format

	File: RBAC_Changes.xml
	Path: \XML
	Description: All RBAC changes as a CLI XML

	.EXAMPLE
	Get-HawkTenantRBACChanges

	Looks for all RBAC changes in the tenant within the search window
	
	#>
	

	Test-EXOConnection
	Send-AIEvent -Event "CmdRun"

	Out-LogFile "Gathering any changes to RBAC configuration" -action

	# Search EXO audit logs for any RBAC changes
	[array]$RBACChanges = Search-AdminAuditLog -Cmdlets New-ManagementRole, New-ManagementRoleAssignment, New-ManagementScope, Remove-ManagementRole, Remove-ManagementRoleAssignment, Set-MangementRoleAssignment, Remove-ManagementScope, Set-ManagementScope -StartDate $Hawk.StartDate -EndDate $Hawk.EndDate

	# If there are any results push them to an output file 
	if ($RBACChanges.Count -gt 0) {
		Out-LogFile ("Found " + $RBACChanges.Count + " Changes made to Roles Based Access Control")
		$RBACChanges | Get-SimpleAdminAuditLog | Out-MultipleFileType -FilePrefix "Simple_RBAC_Changes" -csv
		$RBACChanges | Out-MultipleFileType -FilePrefix "RBAC_Changes" -csv -xml
	}
	# Otherwise report no results found
	else {
		Out-LogFile "No RBAC Changes found."
	}
}