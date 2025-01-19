Function Test-HawkNonInteractiveMode {
    <#
    .SYNOPSIS
        Internal function to detect if Hawk should run in non-interactive mode.
    
    .DESCRIPTION
        Tests whether Hawk should operate in non-interactive mode by checking if any initialization 
        parameters (StartDate, EndDate, DaysToLookBack, FilePath, SkipUpdate) were provided at 
        the command line.
        
        Non-interactive mode is automatically enabled if any of these parameters are present,
        removing the need for users to explicitly specify -NonInteractive.

    .PARAMETER PSBoundParameters
        The PSBoundParameters hashtable from the calling function. Used to check which parameters 
        were explicitly passed to the parent function.

    .OUTPUTS
        [bool] True if any initialization parameters were provided, indicating non-interactive mode.
              False if no initialization parameters were provided, indicating interactive mode.

    .EXAMPLE
        $NonInteractive = Test-HawkNonInteractiveMode -PSBoundParameters $PSBoundParameters

        Checks the bound parameters to determine if non-interactive mode should be enabled.

    .NOTES
        Internal function used by Start-HawkTenantInvestigation and Start-HawkUserInvestigation.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$PSBoundParameters
    )

    return $PSBoundParameters.ContainsKey('StartDate') -or 
           $PSBoundParameters.ContainsKey('EndDate') -or 
           $PSBoundParameters.ContainsKey('DaysToLookBack') -or 
           $PSBoundParameters.ContainsKey('FilePath') -or
           $PSBoundParameters.ContainsKey('SkipUpdate') -or
           $PSBoundParameters.ContainsKey('EnableGeoIPLocation')
}