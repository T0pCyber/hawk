# Internal validation function
Function Test-HawkInvestigationParameter {
    <#
    .SYNOPSIS
        Validates investigation parameters to ensure they meet expected requirements.

    .DESCRIPTION
        This function performs internal validation of parameters used for Hawk investigations, such as StartDate, EndDate, DaysToLookBack, and FilePath. 
        It checks for missing or invalid values and enforces rules around date ranges and file paths, ensuring investigations are configured correctly 
        before proceeding.

    .PARAMETER StartDate
        Specifies the start date of the investigation period. This date must be provided in a valid DateTime format and cannot be more recent than EndDate.
        When used in conjunction with EndDate, the date range must not exceed 365 days.

    .PARAMETER EndDate
        Specifies the end date of the investigation period. This date must be provided in a valid DateTime format and cannot be in the future.
        If StartDate is provided, EndDate must also be specified.

    .PARAMETER DaysToLookBack
        Specifies the number of days to look back from the current date to gather log data. The value must be an integer between 1 and 365.
        This parameter is typically used as an alternative to specifying a StartDate and EndDate.

    .PARAMETER FilePath
        Specifies the directory path where investigation output files will be saved. This path must be valid and accessible.
        The parameter is required in non-interactive mode to ensure logs are written to a specified location.

    .PARAMETER NonInteractive
        A switch parameter that indicates the function is running in non-interactive mode. In this mode, required parameters must be provided upfront,
        as user prompts are disabled. This is typically used in automated scripts or CI/CD pipelines.

    .OUTPUTS
        Returns a custom PowerShell object with two properties:
        - IsValid: A boolean value indicating whether the parameters passed validation.
        - ErrorMessages: An array of error messages explaining why validation failed (if applicable).

    .NOTES
        - The function converts StartDate and EndDate to UTC to ensure consistent date comparisons.
        - If a date range exceeds 365 days or if EndDate is in the future, the function returns a validation error.
        - DaysToLookBack must be between 1 and 365 to comply with log retention policies in Microsoft 365.

    .EXAMPLE
        Test-HawkInvestigationParameter -StartDate "2024-01-01" -EndDate "2024-03-31" -FilePath "C:\Logs" -NonInteractive

        This example validates the parameters for a non-interactive Hawk investigation. The function checks that the FilePath is valid,
        the date range is within limits, and that both StartDate and EndDate are provided.

    .EXAMPLE
        Test-HawkInvestigationParameter -DaysToLookBack 90 -FilePath "C:\Logs"

        This example validates an investigation configured to look back 90 days from the current date. The function ensures that DaysToLookBack
        is within the allowable range and that the FilePath is valid.

    .EXAMPLE
        $validationResult = Test-HawkInvestigationParameter -StartDate "2024-01-01" -EndDate "2024-02-15" -DaysToLookBack 45
        if (-not $validationResult.IsValid) {
            $validationResult.ErrorMessages | ForEach-Object { Write-Host $_ -ForegroundColor Red }
        }

        This example stores the validation result in a variable and outputs any error messages if the parameters failed validation.

    .LINK
        https://cloudforensicator.com/

    .LINK
        https://docs.microsoft.com/en-us/powershell/scripting/

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

        if ($utcEndDate -gt $currentDate) {
            $isValid = $false
            $errorMessages += "EndDate cannot be in the future"
        }

        $daysDifference = ($utcEndDate - $utcStartDate).Days
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
