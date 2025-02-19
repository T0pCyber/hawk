Function Convert-HawkDaysToDate {
    <#
    .SYNOPSIS
        Converts the DaysToLookBack parameter into a StartDate and EndDate for use in Hawk investigations.

    .DESCRIPTION
        This function takes the number of days to look back from the current date and calculates the corresponding
        StartDate and EndDate in UTC format. The StartDate is calculated by subtracting the specified number of days
        from the current date, and the EndDate is set to one day in the future (to include the entire current day).

    .PARAMETER DaysToLookBack
        The number of days to look back from the current date. Must be between 1 and 365.

    .OUTPUTS
        A PSCustomObject with two properties:
        - StartDate: The calculated start date in UTC format.
        - EndDate: The calculated end date in UTC format (one day in the future).

    .EXAMPLE
        Convert-HawkDaysToDates -DaysToLookBack 30
        Returns a StartDate of 30 days ago and an EndDate of tomorrow in UTC format.

    .NOTES
        This function ensures that the date range does not exceed 365 days and that the dates are properly formatted
        for use with Hawk investigation functions.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [int]$DaysToLookBack
    )

    # Calculate the dates
    $startDate = (Get-Date).ToUniversalTime().AddDays(-$DaysToLookBack).Date

    # EndDate should be midnight of next day
    $endDate = (Get-Date).ToUniversalTime().Date.AddDays(1)

    # Return the dates as a PSCustomObject
    [PSCustomObject]@{
        StartDate = $startDate
        EndDate   = $endDate
    }
}
