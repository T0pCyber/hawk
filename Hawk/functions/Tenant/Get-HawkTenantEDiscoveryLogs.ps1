Function Get-HawkTenantEDiscoveryLogs{
    <#
    .SYNOPSIS
        Gets Unified Audit Logs (UAL) data for eDiscovery
    .DESCRIPTION
        Searches the UAL for eDiscovery events

    #>


        # Search UAL audit logs for any Domain configuration changes
    Test-EXOConnection
	Send-AIEvent -Event "CmdRun"

	Out-LogFile "Gathering any eDiscovery logs" -action

	# Search UAL audit logs for any Domain configuration changes
	$eDiscoveryLogs = Get-AllUnifiedAuditLogEntry -UnifiedSearch ("Search-UnifiedAuditLog -RecordType 'Discovery'")
    # If null we found no changes to nothing to do here
    if ($null -eq $eDiscoveryLogs){
        Out-LogFile "No eDiscovery Logs found"
    }

    # If not null then we must have found some events so flag them
    else {
        Out-LogFile "eDiscovery Log have been found." -Notice
        Out-LogFile "Please review these eDiscoveryLogs.csv to validate the activity is legitimate." -Notice
        # Go thru each even and prepare it to output to CSV
        Foreach ($log in $eDiscoveryLogs){
            $log1 = $log.auditdata | ConvertFrom-Json
            $report = $log1  | Select-Object -Property CreationTime,
                Id,
                Operation,
                Workload,
                UserID,
                Case,
                @{Name='CaseID';Expression={($_.ExtendedProperties | Where-Object {$_.Name -eq 'CaseId'}).value}}
                @{Name='Cmdlet';Expression={($_.Parameters | Where-Object {$_.Name -eq 'Cmdlet'}).value}}

            $report | Out-MultipleFileType -fileprefix "eDiscoveryLogs" -csv -append
        }

    }
    }
