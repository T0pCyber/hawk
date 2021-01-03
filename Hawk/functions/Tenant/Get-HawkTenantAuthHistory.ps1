Function Get-HawkTenantAuthHistory {

    <#
    
    .SYNOPSIS
    Gathers 48 hours worth of Unified Audit logs.
    Pulls everyting into a CSV file.

    .DESCRIPTION
    Connects to EXO and searches the unified audit log file only a date time filter.
    Searches in 15 minute increments to ensure that we gather all data.

    Should be used once you have used other commands to determine a "window" that needs more review.

    .OUTPUTS
    File: Audit_Log_Full_<date>.csv
    Path: \Tenant
    Description: Audit data for ALL users over a 48 hour period

    .EXAMPLE
    Get-HawkTenantAuthHistory -StartDate "10/25/2018"

    Gathers 48 hours worth of audit data starting at midnight on October 25th 2018
        
    #>

    Param (
        [Parameter(Mandatory = $true)]
        [datetime]$StartDate,
        [int]$IntervalMinutes = 15
    )

    # # Try to convert the submitted date into [datetime] format
    # try {
    #     [datetime]$DateToStartSearch = Get-Date $StartDate       
    # }
    # catch {
    #     Out-Logfile "[ERROR] - Unable to convert submitted date"
    #     break        
    # }
    
    # Make sure the start date isn't more than 90 days in the past
    if ((Get-Date).adddays(-91) -gt $StartDate) {
        Out-Logfile "[ERROR] - Start date is over 90 days in the past"
        break
    }

    Test-EXOConnection
    Send-AIEvent -Event "CmdRun"

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
            Out-LogFile ("No results found for time period " + $CurrentStart + " - " + $CurrentEnd)
        }
        else {
            $output | Out-MultipleFileType -FilePrefix "Audit_Log_Full_$prefix" -Append -csv
        }

        # Move our start and end times forward
        $currentStart = $currentEnd
        $currentEnd = $currentEnd.AddMinutes($intervalMinutes)

        # Increment our count
        $CurrentCount++
    }
}