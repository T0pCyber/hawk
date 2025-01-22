Function Test-HawkDateParameter {
    <#
    .SYNOPSIS
        Internal helper function that processes and validates date parameters for Hawk investigations.

    .DESCRIPTION
        The Test-HawkDateParmeter function is an internal helper used by Start-HawkTenantInvestigation 
        and Start-HawkUserInvestigation to process date-related parameters. It handles both direct date 
        specifications and the DaysToLookBack parameter, performing initial validation and date conversions.

        The function:
        - Validates the combination of provided date parameters
        - Processes DaysToLookBack into concrete start/end dates
        - Converts dates to UTC format
        - Performs bounds checking on date ranges
        - Handles both absolute dates and relative date calculations

        This is designed as an internal function and should not be called directly by end users.

    .PARAMETER PSBoundParameters
        The PSBoundParameters hashtable from the calling function. Used to check which parameters 
        were explicitly passed to the parent function. Must contain information about whether 
        StartDate, EndDate, and/or DaysToLookBack were provided.

    .PARAMETER StartDate
        The starting date for the investigation period, if specified directly.
        Can be null if using DaysToLookBack instead.
        When provided with EndDate, defines an explicit date range for the investigation.

    .PARAMETER EndDate
        The ending date for the investigation period, if specified directly.
        Can be null if using DaysToLookBack instead.
        When provided with StartDate, defines an explicit date range for the investigation.

    .PARAMETER DaysToLookBack
        The number of days to look back from either the current date or a specified EndDate.
        Must be between 1 and 365.
        Cannot be used together with StartDate.

    .OUTPUTS
        PSCustomObject containing:
        - StartDate [DateTime]: The calculated or provided start date in UTC
        - EndDate [DateTime]: The calculated or provided end date in UTC

    .EXAMPLE
        $dates = Test-HawkDateParmeter -PSBoundParameters $PSBoundParameters -DaysToLookBack 30
        
        Processes a request to look back 30 days from the current date, returning appropriate 
        start and end dates in UTC format.

    .EXAMPLE
        $dates = Test-HawkDateParmeter `
            -PSBoundParameters $PSBoundParameters `
            -StartDate "2024-01-01" `
            -EndDate "2024-01-31"

        Processes explicit start and end dates, validating them and converting to UTC format.

    .EXAMPLE
        $dates = Test-HawkDateParmeter `
            -PSBoundParameters $PSBoundParameters `
            -DaysToLookBack 30 `
            -EndDate "2024-01-31"

        Processes a request to look back 30 days from a specific end date.

    .NOTES
        Author: Jonathan Butler
        Internal Function: This function is not meant to be called directly by users
        Dependencies: Requires PSFramework module for error handling
        Validation: Initial parameter validation only; complete validation is done by Test-HawkInvestigationParameter

    .LINK
        Test-HawkInvestigationParameter

    .LINK
        Start-HawkTenantInvestigation

    .LINK
        Start-HawkUserInvestigation
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$PSBoundParameters,

        [AllowNull()]
        [Nullable[DateTime]]$StartDate,

        [AllowNull()]  
        [Nullable[DateTime]]$EndDate,

        [int]$DaysToLookBack
    )

    # Check if user provided both StartDate AND DaysToLookBack
    if ($PSBoundParameters.ContainsKey('DaysToLookBack') -and $PSBoundParameters.ContainsKey('StartDate')) {
        Stop-PSFFunction -Message "DaysToLookBack cannot be used together with StartDate in non-interactive mode." -EnableException $true
    }

    # Must specify either StartDate or DaysToLookBack 
    if (-not $PSBoundParameters.ContainsKey('DaysToLookBack') -and -not $PSBoundParameters.ContainsKey('StartDate')) {
        Stop-PSFFunction -Message "Either StartDate or DaysToLookBack must be specified in non-interactive mode" -EnableException $true
    }

    # Process DaysToLookBack if provided
    if ($PSBoundParameters.ContainsKey('DaysToLookBack')) {
        if ($DaysToLookBack -lt 1 -or $DaysToLookBack -gt 365) {
            Stop-PSFFunction -Message "DaysToLookBack must be between 1 and 365" -EnableException $true
        }
        else {
            # Handle EndDate with DaysToLookBack but no StartDate
            if ($PSBoundParameters.ContainsKey('EndDate') -and -not $PSBoundParameters.ContainsKey('StartDate')) {
                $EndDateUTC = $EndDate.ToUniversalTime()
                $StartDateUTC = $EndDateUTC.AddDays(-$DaysToLookBack)

                $StartDate = $StartDateUTC
                $EndDate = $EndDateUTC
            }
            else {
                # Convert DaysToLookBack to StartDate/EndDate from "today"
                $ConvertedDates = Convert-HawkDaysToDate -DaysToLookBack $DaysToLookBack
                $StartDate = $ConvertedDates.StartDate
                $EndDate = $ConvertedDates.EndDate
            }
        }
    }

    [PSCustomObject]@{
        StartDate = $StartDate
        EndDate = $EndDate 
    }
}