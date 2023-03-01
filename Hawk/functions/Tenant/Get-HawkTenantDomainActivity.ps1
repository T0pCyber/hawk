# Search for any changes made to RBAC in the search window and report them
Function Get-HawkTenantDomainActivity {
<#
.SYNOPSIS
	Looks for any changes made to M365 Domains. Permissions required to make the changes that thsi function is
	looking for is "Domain Name Administrator" or "Global Administrator
.DESCRIPTION
	Searches the EXO Audit logs for the following commands being run.
	Set-AccpetedDomain
	Add-FederatedDomain
	New-AcceptedDomain
	Update Domain
	Add Verified Domain
	Add Unverified Domain
	.OUTPUTS

	File: Domain_Activity_Changes.csv
	Path: \
	Description: All Domain activity actions

	File: Domain_Activity_Changes.xml
	Path: \XML
	Description: All Domain configuration actions
.EXAMPLE
	Get-HawkTenantDomainActivity

	Searches for all Domain configuration actions
#>

	Test-EXOConnection
	Send-AIEvent -Event "CmdRun"

	Out-LogFile "Gathering any changes to Domain configuration settings" -action

	# Search UAL audit logs for any Domain configuration changes
	$DomainConfigurationEvents = Get-AllUnifiedAuditLogEntry -UnifiedSearch ("Search-UnifiedAuditLog -RecordType 'AzureActiveDirectory' -Operations 'Set-AcceptedDomain','Add-FederatedDomain','Update Domain','Add verified domain', 'Add unverified domain', 'remove unverified domain'")
	# If null we found no changes to nothing to do here
if ($null -eq $DomainConfigurationEvents){
	Out-LogFile "No Domain configuration changes found."
}

# If not null then we must have found some events so flag them
else {
	Out-LogFile "Domain configuration changes found." -Notice
	Out-LogFile "Please review these Domain_Changes_Audit to ensure any changes are legitimate." -Notice

	# Go thru each even and prepare it to output to CSV
	Foreach ($event in $DomainConfigurationEvents){
		$log1 = $event.auditdata | ConvertFrom-Json
		$report = $null
		$result1 =($log1.ModifiedProperties.NewValue).Split('"')

		$result2 = ($log1.ExtendedProperties.Value).Split('"')

	$report = $log1  | Select-Object -Property CreationTime,
			Id,
			Operation,
			ResultStatus,
			Workload,
			UserID,
			@{Name='Domain';Expression={$result1[1]}},
			@{Name='User Agent String';Expression={$result2[3]}}
	$report | Out-MultipleFileType -fileprefix "Domain_Changes_Audit" -csv -append
	}

}
}
