Function Get-HawkTenantRBACChange {
	<#
    .SYNOPSIS
        Looks for any changes made to Role-Based Access Control (RBAC).
    .DESCRIPTION
        Searches the Unified Audit Logs for commands related to RBAC management including role,
        role assignment, role entry, role group, and management scope changes. This helps track
        administrative permission changes across the tenant.

        The function searches for operations including:
        - Role management (New/Remove/Set-ManagementRole)
        - Role assignments (New/Remove/Set-ManagementRoleAssignment)
        - Management scopes (New/Remove/Set-ManagementScope)
        - Role entries (New/Remove/Set-ManagementRoleEntry)
        - Role groups (New/Remove/Set/Add/Remove-RoleGroup*)

    .OUTPUTS
        File: Simple_RBAC_Changes.csv
        Path: \Tenant
        Description: Simplified view of RBAC changes in CSV format

        File: RBAC_Changes.csv
        Path: \Tenant
        Description: Detailed RBAC changes in CSV format

        File: RBAC_Changes.json
        Path: \Tenant
        Description: Raw audit data in JSON format for detailed analysis

        File: RBAC_Changes_Raw.json
        Path: \Tenant
        Description: Complete raw audit logs in JSON format

    .EXAMPLE
        Get-HawkTenantRBACChange

        Searches for and reports all RBAC changes in the tenant within the configured search window.
    #>
	[CmdletBinding()]
	param()

	# Verify EXO connection and send telemetry
	Test-EXOConnection
	Send-AIEvent -Event "CmdRun"

	Out-LogFile "Gathering any changes to RBAC configuration" -action

	# Define the operations to search for
	[array]$RBACOperations = @(
		"New-ManagementRole",
		"Remove-ManagementRole",
		"New-ManagementRoleAssignment",
		"Remove-ManagementRoleAssignment",
		"Set-ManagementRoleAssignment",
		"New-ManagementScope",
		"Remove-ManagementScope",
		"Set-ManagementScope",
		"New-ManagementRoleEntry",
		"Remove-ManagementRoleEntry",
		"Set-ManagementRoleEntry",
		"New-RoleGroup",
		"Remove-RoleGroup",
		"Set-RoleGroup",
		"Add-RoleGroupMember",
		"Remove-RoleGroupMember"
	)

	# Create tenant folder if it doesn't exist
	$TenantPath = Join-Path -Path $Hawk.FilePath -ChildPath "Tenant"
	if (-not (Test-Path -Path $TenantPath)) {
		New-Item -Path $TenantPath -ItemType Directory -Force | Out-Null
	}

	try {
		# Search Unified Audit Logs for RBAC changes
		[array]$RBACChanges = Search-UnifiedAuditLog -RecordType ExchangeAdmin `
			-Operations $RBACOperations `
			-StartDate $Hawk.StartDate `
			-EndDate $Hawk.EndDate `
			-ResultSize 5000

		# Process results if any found
		if ($RBACChanges.Count -gt 0) {
			Out-LogFile ("Found " + $RBACChanges.Count + " changes made to Roles-Based Access Control")

			# Write raw audit data JSON for reference
			$RawJsonPath = Join-Path -Path $TenantPath -ChildPath "RBAC_Changes_Raw.json"
			$RBACChanges | Select-Object -ExpandProperty AuditData | Out-File -FilePath $RawJsonPath

			# Parse changes using Get-SimpleUnifiedAuditLog
			$ParsedChanges = $RBACChanges | Get-SimpleUnifiedAuditLog

			# Output results if successfully parsed
			if ($ParsedChanges) {
				# Write simple format for easy analysis
				$ParsedChanges | Out-MultipleFileType -FilePrefix "Simple_RBAC_Changes" -csv -json

				# Write full audit logs for complete record
				$RBACChanges | Out-MultipleFileType -FilePrefix "RBAC_Changes" -csv -json
			}
			else {
				Out-LogFile "Error: Failed to parse RBAC changes" -Notice
			}
		}
		else {
			Out-LogFile "No RBAC changes found."
		}
	}
	catch {
		Out-LogFile "Error searching for RBAC changes: $($_.Exception.Message)" -Notice
		Write-Error -ErrorRecord $_ -ErrorAction Continue
	}
}