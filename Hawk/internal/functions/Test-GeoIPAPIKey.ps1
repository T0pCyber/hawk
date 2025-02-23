Function Test-GeoIPAPIKey {
        <#
    .SYNOPSIS
        Create global variable $Hawk for use by all Hawk cmdlets.
    .DESCRIPTION
        Creates the global variable $Hawk and populates it with information needed by the other Hawk cmdlets.

        * Checks for latest version of the Hawk module
        * Creates path for output files
        * Records target start and end dates for searches (in UTC)
    .PARAMETER Force
        Switch to force the function to run and allow the variable to be recreated
    .PARAMETER SkipUpdate
        Skips checking for the latest version of the Hawk Module
    .PARAMETER DaysToLookBack
        Defines the # of days to look back in the availible logs.
        Valid values are 1-90
    .PARAMETER StartDate
        First day that data will be retrieved (in UTC)
    .PARAMETER EndDate
        Last day that data will be retrieved (in UTC)
    .PARAMETER FilePath
        Provide an output file path.
    .PARAMETER NonInteractive
    Switch to run the command in non-interactive mode. Requires all necessary parameters
    to be provided via command line rather than through interactive prompts.
    .PARAMETER EnableGeoIPLocation
		Switch to enable resolving IP addresses to geographic locations in the investigation.
		This option requires an active internet connection and may increase the time needed to complete the investigation.
		Providing this parameter automatically enables non-interactive mode.

        REQUIRED: An API key from ipstack.com is required to use this feature.
    .OUTPUTS
        Creates the $Hawk global variable and populates it with a custom PS object with the following properties

        Property Name	Contents
        ==========		==========
        FilePath		Path to output files
        DaysToLookBack	Number of day back in time we are searching
        StartDate		Calculated start date for searches based on DaysToLookBack (UTC)
        EndDate			One day in the future (UTC)
        WhenCreated		Date and time that the variable was created (UTC)
    .EXAMPLE
        Initialize-HawkGlobalObject -Force

        This Command will force the creation of a new $Hawk variable even if one already exists.
    #>
    param (
        [Parameter(Mandatory)]
        [string]$Key
    )

    process {

        # Check for empty string or null entered by the user
        if ([string]::IsNullOrEmpty($Key)) {
            Out-LogFile "Failed to update IP Stack API key: Cannot bind argument to parameter 'Key' because it is an empty string." -isError
            return $false
        }

        # Check length is 32 characters
        if ($Key.Length -ne 32) {
            return $false
        }

        # Check each character is valid hex using regex
        # ADD: CALL IPSTACK API AND DEPENDING ON RESULT, RETURN TRUE OR FALSE
        return ($Key -match '^[0-9a-f]{32}$')
    }
}