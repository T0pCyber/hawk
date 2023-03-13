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
	BEGIN{
		Test-EXOConnection
		Send-AIEvent -Event "CmdRun"
		Out-LogFile "Gathering any changes to Domain configuration settings" -action
	}
	PROCESS{
		# Search UAL audit logs for any Domain configuration changes
		$DomainConfigurationEvents = Get-AllUnifiedAuditLogEntry -UnifiedSearch ("Search-UnifiedAuditLog -RecordType 'AzureActiveDirectory' -Operations 'Set-AcceptedDomain','Add-FederatedDomain','Update Domain','Add verified domain', 'Add unverified domain', 'remove unverified domain'")
		# If null we found no changes to nothing to do here
			if ($null -eq $DomainConfigurationEvents){
			Out-LogFile "No Domain configuration changes found."
		}
		# If not null then we must have found some events so flag them
		else{
			Out-LogFile "Domain configuration changes found." -Notice
			Out-LogFile "Please review these Domain_Changes_Audit to ensure any changes are legitimate." -Notice

			# Go thru each even and prepare it to output to CSV
			Foreach ($event in $DomainConfigurationEvents){
				$log1 = $event.auditdata | ConvertFrom-Json
				$domainarray = $log1.ModifiedProperties
				$useragentarray = $log1.ExtendedProperties
				if ($domainarray){
					$result1 = ($log1.ModifiedProperties.NewValue).Split('"')
					$Domain = $result1[1]<# Action to perform if the condition is true #>
				}
				else {
					$Domain = "No Domain Value Found"
				}
				if ($useragentarray){
					$result2 = ($log1.ExtendedProperties.Value).Split('"')
					$UserAgentString = $result2[3]
				}
				else {
					$UserAgentString = "No User Agent String Found"
				}
				#$result2 = ($log1.ExtendedProperties.Value).Split('"')
				#$UserAgentString = $result2[3]
			$newlog = $log1  | Select-Object -Property CreationTime,
				Id,
				Workload,
				Operation,
				ResultStatus,
				UserID,
				@{Name='Domain';Expression={$Domain}},
        		@{Name='User Agent String';Expression={$UserAgentString}},
				@{Name='Target';Expression={($_.Target.ID)}}
			$newlog | Out-MultipleFileType -fileprefix "Domain_Changes_Audit" -csv -append
			}
		}

  $report = $log1  | Select-Object -Property Id,
			Operation,
			ResultStatus,
			Workload,
			UserID,
			@{Name='Domain';Expression={$result1[1]}},
			@{Name='User Agent String';Expression={$result2[3]}}
	$report | Out-MultipleFileType -fileprefix "Domain_Changes_Audit" -csv -json -append
	}

END{
	Out-LogFile "Completed gathering Domain configuration changes"
}
}#End Function Get-HawkTenantDomainActivity
