Function Test-HawkInvestigationParameter {
    <#
    .SYNOPSIS
        Validates parameters for Hawk investigation commands in both interactive and non-interactive modes.

    .DESCRIPTION
        The Test-HawkInvestigationParameters function performs comprehensive validation of parameters used in Hawk's investigation commands. 
        It ensures that all required parameters are present and valid when running in non-interactive mode, while also validating date ranges 
        and other constraints that apply in both modes.

        The function validates:
        - File path existence and validity
        - Presence of required date parameters in non-interactive mode
        - Date range constraints (max 365 days, start before end)
        - DaysToLookBack value constraints (1-365 days)
        - Future date restrictions
        
        When validation fails, the function returns detailed error messages explaining which validations failed and why.
        These messages can be used to provide clear guidance to users about how to correct their parameter usage.

    .PARAMETER StartDate
        The beginning date for the investigation period. Must be provided with EndDate in non-interactive mode.
        Cannot be later than EndDate or result in a date range exceeding 365 days.

    .PARAMETER EndDate
        The ending date for the investigation period. Must be provided with StartDate in non-interactive mode.
        Cannot be more than one day in the future or result in a date range exceeding 365 days.

    .PARAMETER DaysToLookBack
        Alternative to StartDate/EndDate. Specifies the number of days to look back from the current date.
        Must be between 1 and 365. Cannot be used together with StartDate/EndDate parameters.

    .PARAMETER FilePath
        The file system path where investigation results will be stored.
        Must be a valid file system path. Required in non-interactive mode.

    .PARAMETER NonInteractive
        Switch that indicates whether Hawk is running in non-interactive mode.
        When true, enforces stricter parameter validation requirements.

    .OUTPUTS
        PSCustomObject with two properties:
        - IsValid (bool): Indicates whether all validations passed
        - ErrorMessages (string[]): Array of error messages when validation fails

    .NOTES
        This is an internal function used by Start-HawkTenantInvestigation and Start-HawkUserInvestigation.
        It is not intended to be called directly by users of the Hawk module.
        
        All datetime operations use UTC internally for consistency.
    #>
    [CmdletBinding()]
    param (
        [DateTime]$StartDate,
        [DateTime]$EndDate,
        [int]$DaysToLookBack,
        [string]$FilePath,
        [switch]$NonInteractive
    )

    # Store validation results
    $isValid = $true
    $errorMessages = @()

    # If in non-interactive mode, validate required parameters
    if ($NonInteractive) {
        # Validate FilePath
        if ([string]::IsNullOrEmpty($FilePath)) {
            $isValid = $false
            $errorMessages += "FilePath parameter is required in non-interactive mode"
        }
        elseif (-not (Test-Path -Path $FilePath -IsValid)) {
            $isValid = $false
            $errorMessages += "Invalid file path provided: $FilePath"
        }

        # Validate date parameters
        if (-not ($StartDate -or $DaysToLookBack)) {
            $isValid = $false
            $errorMessages += "Either StartDate or DaysToLookBack must be specified in non-interactive mode"
        }

        if ($StartDate -and -not $EndDate) {
            $isValid = $false
            $errorMessages += "EndDate must be specified when using StartDate in non-interactive mode"
        }
    }

    # Validate DaysToLookBack regardless of mode
    if ($DaysToLookBack) {
        if ($DaysToLookBack -lt 1 -or $DaysToLookBack -gt 365) {
            $isValid = $false
            $errorMessages += "DaysToLookBack must be between 1 and 365"
        }
    }

    # Validate date range if both dates provided
    if ($StartDate -and $EndDate) {
        # Convert to UTC for consistent comparison
        $utcStartDate = $StartDate.ToUniversalTime()
        $utcEndDate = $EndDate.ToUniversalTime()
        $currentDate = (Get-Date).ToUniversalTime()

        if ($utcStartDate -gt $utcEndDate) {
            $isValid = $false
            $errorMessages += "StartDate must be before EndDate"
        }

        # Compare against tomorrow to allow for the extra day
        $tomorrow = $currentDate.Date.AddDays(1)
        if ($utcEndDate -gt $tomorrow) {
            $isValid = $false
            $errorMessages += "EndDate cannot be more than one day in the future"
        }

        # Use dates for day difference calculation
        $daysDifference = ($utcEndDate.Date - $utcStartDate.Date).Days
        if ($daysDifference -gt 365) {
            $isValid = $false
            $errorMessages += "Date range cannot exceed 365 days"
        }
    }

    # Return validation results
    [PSCustomObject]@{
        IsValid = $isValid
        ErrorMessages = $errorMessages
    }
}