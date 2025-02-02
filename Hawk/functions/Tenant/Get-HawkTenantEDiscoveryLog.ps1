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
        for the configured time period and export the results to CSV and JSON formats.

    .EXAMPLE
        $logs = Get-HawkTenantEDiscoveryLog
        $logs | Where-Object {$_.Operation -eq "SearchCreated"}

        This example shows how to retrieve eDiscovery logs and filter for specific
        operations like new search creation.

    .OUTPUTS
        File: Simple_eDiscoveryLogs.csv/.json
        Path: \Tenant
        Description: Simplified view of eDiscovery activities.

        File: eDiscoveryLogs.csv/.json
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
    # Check if Hawk object exists and is fully initialized
    if (Test-HawkGlobalObject) {
        Initialize-HawkGlobalObject
    }

    Test-EXOConnection
    Send-AIEvent -Event "CmdRun"

    Out-LogFile "Gathering any eDiscovery logs" -action

    # Search UAL audit logs for any eDiscovery activities
    $eDiscoveryLogs = Get-AllUnifiedAuditLogEntry -UnifiedSearch ("Search-UnifiedAuditLog -RecordType 'Discovery'")
    
    if ($null -eq $eDiscoveryLogs) {
        Out-LogFile "Get-HawkTenantEDiscoveryLog completed successfully" -Information
        Out-LogFile "No eDiscovery Logs found" -Action
    }
    else {
        Out-LogFile "eDiscovery Logs have been found." -Notice
        Out-LogFile "Please review these eDiscoveryLogs.csv to validate the activity is legitimate." -Notice

        # Process and output both simple and detailed formats
        $ParsedLogs = $eDiscoveryLogs | Get-SimpleUnifiedAuditLog
        if ($ParsedLogs) {
            Out-LogFile "Writing parsed eDiscovery log data" -Action
            $ParsedLogs | Out-MultipleFileType -FilePrefix "Simple_eDiscoveryLogs" -csv -json
            $eDiscoveryLogs | Out-MultipleFileType -FilePrefix "eDiscoveryLogs" -csv -json
        }
        else {
            Out-LogFile "Error: Failed to parse eDiscovery log data" -isError
        }
    }
}