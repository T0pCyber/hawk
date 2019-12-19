
Function Get-HawkTenantAzureAuditLog {
	
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

	Test-EXOConnection
	Send-AIEvent -Event "CmdRun"
	
	# Make sure our variables are null
	$AzureApplicationActivityEvents = $null

    Out-LogFile "Searching Unified Audit Logs Azure Activities" -Action 
	Out-LogFile "Searching for Application Activities"

	# Search the unified audit log for events related to applciation activity
	# https://docs.microsoft.com/en-us/microsoft-365/security/office-365-security/detect-and-remediate-illicit-consent-grants
	$AzureApplicationActivityEvents = Get-AllUnifiedAuditLogEntry -UnifiedSearch ("Search-UnifiedAuditLog -RecordType 'AzureActiveDirectory' -Operations 'Add OAuth2PermissionGrant.','Consent to application.' ")

	# If null we found no changes to nothing to do here
	if ($null -eq $AzureApplicationActivityEvents){
		Out-LogFile "No Application related events found in the search time frame."
	}

	# If not null then we must have found some events so flag them
	else {
		Out-LogFile "Application Rights Activity found." -Notice
		Out-LogFile "Please review these Azure_Application_Audit.csv to ensure any changes are legitimate." -Notice

		# Go thru each even and prepare it to output to CSV
		Foreach ($event in $AzureApplicationActivityEvents){
		
			$event.auditdata | ConvertFrom-Json | Select-Object -Property Id,
				Operation,
				ResultStatus,
				Workload,
				ClientIP,
				UserID,
				@{Name='ActorUPN';Expression={($_.ExtendedProperties | Where-Object {$_.Name -eq 'actorUPN'}).value}},
				@{Name='targetName';Expression={($_.ExtendedProperties | Where-Object {$_.Name -eq 'targetName'}).value}},
				@{Name='env_time';Expression={($_.ExtendedProperties | Where-Object {$_.Name -eq 'env_time'}).value}},
				@{Name='correlationId';Expression={($_.ExtendedProperties | Where-Object {$_.Name -eq 'correlationId'}).value}}`
				| Out-MultipleFileType -fileprefix "Azure_Appliction_Audit" -csv -append
		}
	}
}
