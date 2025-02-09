Function Get-HawkTenantUnifiedAuditLog {
    <#
    .SYNOPSIS
        Retrieves comprehensive Unified Audit Log (UAL) data for a 48-hour period.
    
    .DESCRIPTION
        This function searches the Microsoft 365 Unified Audit Log in 15-minute intervals over a 48-hour period
        starting from a specified date. The interval-based approach ensures reliable data collection for high-volume
        environments while avoiding throttling limits.
    
        The function retrieves all audit events across all record types, providing both simplified and detailed views 
        of tenant-wide activity. This is particularly useful when investigating specific time windows identified 
        by other Hawk functions.
    
        Due to UAL retention limits, the start date cannot be more than 90 days in the past.
    
    .PARAMETER StartDate 
        The beginning date/time for audit log collection. The function will collect 48 hours of logs from this point.
        Cannot be more than 90 days in the past.
        Format: MM/DD/YYYY
    
    .PARAMETER IntervalMinutes
        Duration of each collection interval in minutes. Defaults to 15 minutes.
        Smaller intervals help manage large data sets but increase execution time.
        Larger intervals are faster but may miss data in high-volume environments.
    
    .OUTPUTS
        File: Simple_Unified_Audit_Log.csv/.json
        Path: \Tenant
        Description: Flattened, human-readable audit data optimized for analysis
    
        File: Unified_Audit_Log.csv/.json
        Path: \Tenant
        Description: Complete audit data with full detail and nested structures
    
    .EXAMPLE
        Get-HawkTenantUnifiedAuditLog -StartDate "10/25/2023"
    
        Collects all UAL records from midnight October 25th 2023 through October 27th 2023,
        processing in 15-minute intervals and creating both simplified and detailed outputs.
    
    .EXAMPLE
        Get-HawkTenantUnifiedAuditLog -StartDate "10/25/2023" -IntervalMinutes 30
    
        Same as above but uses 30-minute collection intervals. Useful for environments with lower
        audit log volume where longer intervals won't risk missing data.
    #>
    Param (
        [Parameter(Mandatory = $true)]
        [datetime]$StartDate,
        [int]$IntervalMinutes = 15
    )

    # Check if Hawk object exists and is fully initialized
    if (Test-HawkGlobalObject) {
        Initialize-HawkGlobalObject
    }

    
    # Make sure the start date isn't more than 90 days in the past
    if ((Get-Date).adddays(-91) -gt $StartDate) {
        Out-Logfile "Start date is over 90 days in the past" -isError
        break
    }

    Test-EXOConnection

    # Setup inial start and end time for the search
    [datetime]$CurrentStart = $StartDate
    [datetime]$CurrentEnd = $StartDate.AddMinutes($IntervalMinutes)

    # Hard stop for the end time for 48 hours this is to be a good citizen and to ensure that we actually get the data back
    [datetime]$end = $StartDate.AddHours(48)

    # Setup our file prefix so we can run multiple times with out collision
    [string]$prefix = Get-Date ($StartDate) -UFormat %Y_%d_%m

    # Current count so we can setup a file name and other stuff
    [int]$CurrentCount = 0

    # Create while loop so we go thru things in intervals until we hit the end
    while ($currentStart -lt $end) {
        # Pull the unified audit log results
        [array]$output = Get-AllUnifiedAuditLogEntry -UnifiedSearch "Search-UnifiedAuditLog" -StartDate $currentStart -EndDate $currentEnd

        # See if we have results if so push to csv file
        if ($null -eq $output) {
            Out-LogFile "Get-HawkTenantAuthHistory completed successfully" -Information
            Out-LogFile ("No results found for time period " + $CurrentStart + " - " + $CurrentEnd) -action
        }
        else {
            $output | Out-MultipleFileType -FilePrefix "Audit_Log_Full_$prefix" -Append -csv -json
        }

        # Move our start and end times forward
        $currentStart = $currentEnd
        $currentEnd = $currentEnd.AddMinutes($intervalMinutes)

        # Increment our count
        $CurrentCount++
    }
}