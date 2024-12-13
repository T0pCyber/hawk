Function Get-HawkTenantAuthHistory {
<#
.SYNOPSIS
    Gathers 48 hours worth of Unified Audit logs.
    Pulls everything into a CSV file.
.DESCRIPTION
    Connects to EXO and searches the unified audit log file only a date time filter.
    Searches in 15-minute increments to ensure that we gather all data.
    Should be used once you have used other commands to determine a "window" that needs more review.
.PARAMETER StartDate
    Start date of authentication audit log search
.PARAMETER IntervalMinutes
    Time interval for increments
.OUTPUTS
    File: Audit_Log_Full_<date>.csv
    Path: \Tenant
    Description: Audit data for ALL users over a 48-hour period
.EXAMPLE
    Get-HawkTenantAuthHistory -StartDate "10/25/2018"

    Gathers 48 hours worth of audit data starting at midnight on October 25th, 2018
#>

    Param (
        [Parameter(Mandatory = $true)]
        [datetime]$StartDate,
        [int]$IntervalMinutes = 15
    )

    # Ensure the start date is in UTC
    $StartDate = $StartDate.ToUniversalTime()

    # Make sure the start date isn't more than 90 days in the past
    if ((Get-Date).AddDays(-91).ToUniversalTime() -gt $StartDate) {
        Out-Logfile "[ERROR] - Start date is over 90 days in the past"
        break
    }

    Test-EXOConnection

    # Set up initial start and end time for the search in UTC
    [datetime]$CurrentStart = $StartDate
    [datetime]$CurrentEnd = $StartDate.AddMinutes($IntervalMinutes).ToUniversalTime()

    # Hard stop for the end time for 48 hours (in UTC)
    [datetime]$end = $StartDate.AddHours(48).ToUniversalTime()

    # Set up our file prefix so we can run multiple times without collision
    [string]$prefix = Get-Date ($StartDate) -UFormat %Y_%d_%m

    # Current count so we can set up a file name and other stuff
    [int]$CurrentCount = 0

    # Create while loop to process intervals until we hit the end
    while ($CurrentStart -lt $end) {
        # Pull the unified audit log results
        [array]$output = Get-AllUnifiedAuditLogEntry -UnifiedSearch "Search-UnifiedAuditLog" -StartDate $CurrentStart -EndDate $CurrentEnd

        # See if we have results; if so, push to CSV file
        if ($null -eq $output) {
            Out-LogFile ("No results found for time period " + $CurrentStart + " - " + $CurrentEnd)
        }
        else {
            $output | Out-MultipleFileType -FilePrefix "Audit_Log_Full_$prefix" -Append -csv -json
        }

        # Move our start and end times forward in UTC
        $CurrentStart = $CurrentEnd
        $CurrentEnd = $CurrentEnd.AddMinutes($IntervalMinutes).ToUniversalTime()

        # Increment our count
        $CurrentCount++
    }
}
