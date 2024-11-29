Function Get-HawkTenantEDiscoveryLog {
    <#
    .SYNOPSIS
        Gets Unified Audit Logs (UAL) data for eDiscovery
    .DESCRIPTION
        Searches the Unified Audit Log (UAL) for eDiscovery events and activities.
        This includes searches, exports, and management activities related to
        eDiscovery cases. The function checks for any eDiscovery activities within
        the timeframe specified in the Hawk global configuration object.
        
        The results can help identify:
        * When eDiscovery searches were performed
        * Who performed eDiscovery activities
        * Which cases were accessed or modified
        * What operations were performed

    .EXAMPLE
        Get-HawkTenantEDiscoveryLog

        This will search for all eDiscovery-related activities in the Unified Audit Log
        for the configured time period and export the results to CSV format.

    .EXAMPLE
        $logs = Get-HawkTenantEDiscoveryLog
        $logs | Where-Object {$_.Operation -eq "SearchCreated"}

        This example shows how to retrieve eDiscovery logs and filter for specific
        operations like new search creation.

    .OUTPUTS
        File: eDiscoveryLogs.csv
        Path: \Tenant
        Description: Contains all eDiscovery activities found in the UAL with fields for:
        - CreationTime: When the activity occurred
        - Id: Unique identifier for the activity
        - Operation: Type of eDiscovery action performed
        - Workload: The workload where the activity occurred
        - UserID: User who performed the action
        - Case: eDiscovery case name
        - CaseId: Unique identifier for the eDiscovery case
        - Cmdlet: Command that was executed (if applicable)
    #>
    # Search UAL audit logs for any Domain configuration changes
    Test-EXOConnection
    Send-AIEvent -Event "CmdRun"

    Out-LogFile "Gathering any eDiscovery logs" -action

    # Search UAL audit logs for any Domain configuration changes
    $eDiscoveryLogs = Get-AllUnifiedAuditLogEntry -UnifiedSearch ("Search-UnifiedAuditLog -RecordType 'Discovery'")
    # If null we found no changes to nothing to do here
    if ($null -eq $eDiscoveryLogs) {
        Out-LogFile "No eDiscovery Logs found"
    }

    # If not null then we must have found some events so flag them
    else {
        Out-LogFile "eDiscovery Log have been found." -Notice
        Out-LogFile "Please review these eDiscoveryLogs.csv to validate the activity is legitimate." -Notice
        # Go thru each even and prepare it to output to CSV
        Foreach ($log in $eDiscoveryLogs) {
            $log1 = $log.auditdata | ConvertFrom-Json
            $report = $log1  | Select-Object -Property CreationTime,
            Id,
            Operation,
            Workload,
            UserID,
            Case,
            @{Name = 'CaseID'; Expression = { ($_.ExtendedProperties | Where-Object { $_.Name -eq 'CaseId' }).value } },
            @{Name = 'Cmdlet'; Expression = { ($_.Parameters | Where-Object { $_.Name -eq 'Cmdlet' }).value } }

            $report | Out-MultipleFileType -fileprefix "eDiscoveryLogs" -csv -append
        }

    }
}
