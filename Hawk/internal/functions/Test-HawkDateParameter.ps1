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

    .NOTES
        Author: Jonathan Butler
        Internal Function: This function is not meant to be called directly by users
        Dependencies: Requires PSFramework module for error handling
        Validation: Initial parameter validation only; complete validation is done by Test-HawkInvestigationParameter
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
        
        if ($PSBoundParameters.ContainsKey('EndDate') -and -not $PSBoundParameters.ContainsKey('StartDate')) {
            # Check EndDate is not more than one day in future
            $tomorrow = (Get-Date).ToUniversalTime().Date.AddDays(1)
            if ($EndDate.ToUniversalTime().Date -gt $tomorrow) {
                Stop-PSFFunction -Message "EndDate cannot be more than one day in the future" -EnableException $true
            }

            $EndDateUTC = $EndDate.ToUniversalTime().Date.AddDays(1)
            $StartDateUTC = $EndDate.ToUniversalTime().Date.AddDays(-$DaysToLookBack)

            $StartDate = $StartDateUTC
            $EndDate = $EndDateUTC
        }
        else {
            # Convert DaysToLookBack to StartDate/EndDate
            $ConvertedDates = Convert-HawkDaysToDate -DaysToLookBack $DaysToLookBack
            $StartDate = $ConvertedDates.StartDate
            $EndDate = $ConvertedDates.EndDate
        }
    }
    else {
        # For explicit start/end dates
        if ($StartDate) {
            $StartDate = $StartDate.ToUniversalTime().Date
        }

        if ($EndDate) {
            # Validate against tomorrow to allow for the extra day
            $tomorrow = (Get-Date).ToUniversalTime().Date.AddDays(1)
            if ($EndDate.ToUniversalTime().Date -gt $tomorrow) {
                Stop-PSFFunction -Message "EndDate cannot be more than one day in the future" -EnableException $true
            }
            # Add one day to include full end date
            $EndDate = $EndDate.ToUniversalTime().Date.AddDays(1)
        }

        # Validate date range
        if ($StartDate -and $EndDate) {
            if ($StartDate -gt $EndDate) {
                Stop-PSFFunction -Message "StartDate must be before EndDate" -EnableException $true
            }

            $daysDifference = ($EndDate.Date - $StartDate.Date).Days
            if ($daysDifference -gt 365) {
                Stop-PSFFunction -Message "Date range cannot exceed 365 days" -EnableException $true
            }
        }
    }

    [PSCustomObject]@{
        StartDate = $StartDate
        EndDate = $EndDate 
    }
}