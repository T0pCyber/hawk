Function Get-HawkTenantEntraIDAuditLog {
    <#
    .SYNOPSIS
        Retrieves Microsoft Entra ID audit logs using Microsoft Graph API.
    
    .DESCRIPTION
        This function queries the Microsoft Graph API to retrieve Entra ID audit logs. Due to 
        API limitations, it can only retrieve logs for the past 30 days from the current date,
        regardless of the date range configured in Hawk.

        The function will warn if the configured Hawk date range extends beyond the available
        30-day window, but will still retrieve all available logs within the allowed period.

        All retrieved audit log entries are exported in both CSV and JSON formats without
        any filtering or modification.

    .OUTPUTS
        File: EntraIDAuditLogs.csv
        Path: \Tenant
        Description: Complete Entra ID audit log entries from the last 30 days in CSV format

        File: EntraIDAuditLogs.json
        Path: \Tenant
        Description: Complete Entra ID audit log entries from the last 30 days in JSON format

    .EXAMPLE
        Get-HawkTenantEntraIDAuditLog

        Retrieves all available Entra ID audit logs from the past 30 days, regardless of
        the date range configured in Hawk.

    .NOTES
        Author: Jonathan Butler
        Version: 1.0
        
        Requires the following Microsoft Graph permissions:
        - AuditLog.Read.All
        - Directory.Read.All

        IMPORTANT: The Microsoft Graph API for directory audit logs has a strict 30-day
        lookback limit from the current date. Any configured date ranges in Hawk that
        extend beyond this window will be noted, but the function will still retrieve
        all available logs within the allowed 30-day period.

    .LINK 
        https://learn.microsoft.com/en-us/graph/api/directoryaudit-list
    #>
    [CmdletBinding()]
    param()

    # Check if Hawk object exists and is fully initialized
    if (Test-HawkGlobalObject) {
        Initialize-HawkGlobalObject
    }

    Test-GraphConnection
    Send-AIEvent -Event "CmdRun"

    Out-LogFile "Gathering Entra ID audit log" -Action

    # Create tenant folder if it doesn't exist
    $TenantPath = Join-Path -Path $Hawk.FilePath -ChildPath "Tenant"
    if (-not (Test-Path -Path $TenantPath)) {
        New-Item -Path $TenantPath -ItemType Directory -Force | Out-Null
    }

    try {
        # Calculate 30 days ago from current date
        $thirtyDaysAgo = (Get-Date).AddDays(-30).Date 
        
        # Warn if Hawk date range extends beyond available window
        if ($Hawk.StartDate -lt $thirtyDaysAgo) {
            Out-LogFile "Note: Entra ID audit logs are only available for the past 30 days. Earlier dates will be ignored." -Information
        }

        # Build filter string using 30-day limit
        $filterString = "activityDateTime ge $($thirtyDaysAgo.ToString('yyyy-MM-ddTHH:mm:ssZ')) and activityDateTime le $((Get-Date).ToString('yyyy-MM-ddTHH:mm:ssZ'))"
        
        Out-LogFile "Retrieving audit logs for the past 30 days" -Action

        # Get all audit logs for the date range
        [array]$auditLogs = Get-MgAuditLogDirectoryAudit -Filter $filterString -All

        if ($auditLogs.Count -gt 0) {
            Out-LogFile ("Found " + $auditLogs.Count + " audit log entries") -Information
            
            # Export the complete objects to both CSV and JSON
            $auditLogs | Out-MultipleFileType -FilePrefix "EntraIDAuditLogs" -csv -json
        }
        else {
            Out-LogFile "Get-HawkTenantEntraIDAuditLog completed successfully" -Information
            Out-LogFile "No audit logs found for the specified time period" -Action
        }
    }
    catch {
        Out-LogFile "Error retrieving Entra ID audit logs: $($_.Exception.Message)" -isError
        Write-Error -ErrorRecord $_ -ErrorAction Continue
    }
}