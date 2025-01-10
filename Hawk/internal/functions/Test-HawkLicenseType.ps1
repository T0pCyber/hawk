function Test-HawkLicenseType {
    <#
    .SYNOPSIS
        Identifies the Microsoft 365 license type (E5, E3, or other) for the current tenant and returns the corresponding retention period.

    .DESCRIPTION
        The `Test-HawkLicenseType` function retrieves the list of subscribed SKUs for the tenant using the Microsoft Graph API.
        It checks the license type based on the SkuPartNumber and returns the appropriate retention period in days:
        - 365 days for E5 licenses (including equivalents like Developer Pack E5).
        - 180 days for E3 licenses.
        - 90 days as a default retention period if no matching license is found.

    .EXAMPLE
        PS C:\> Test-HawkLicenseType
        Returns the retention period based on the tenant's license type.

    .NOTES
        Author: Jonathan Butler
        Last Updated: January 9, 2025
        This function uses Microsoft Graph cmdlets to retrieve the tenant's license information.
        
    .REQUIREMENTS
        - Microsoft.Graph module must be installed and authenticated.
        - User must have permission to query the tenant's subscription details.

    .PARAMETER None
        This function does not take any parameters.

    .RETURNS
        [int] - Retention period in days:
                - 365 for E5 or equivalent licenses.
                - 180 for E3 or equivalent licenses.
                - 90 by default if no matching license is found.

    .INPUTS
        None. The function does not accept input from the pipeline.

    .OUTPUTS
        [int] - Retention period in days.

    .COMPONENT
        Microsoft Graph PowerShell Module

    .LINK
        https://learn.microsoft.com/en-us/powershell/microsoftgraph
    #>

    [CmdletBinding()]
    [OutputType([int])]
    param()

    try {
        # Get tenant subscriptions
        $subscriptions = Get-MgSubscribedSku

        # Check for E5 or equivalent license
        if ($subscriptions.SkuPartNumber -match 'ENTERPRISEPREMIUM|SPE_E5|DEVELOPERPACK_E5|M365_E5') {
            return 365 # E5 license retention period
        }

        # Check for E3 or equivalent license
        if ($subscriptions.SkuPartNumber -match 'ENTERPRISEPACK|M365_E3|DEVELOPERPACK_E3') {
            return 180 # E3 license retention period
        }

        # Default retention period
        return 90
    }
    catch {
        Out-LogFile "Unable to determine license type. Defaulting to 90 days retention." -isError
        return 90
    }
}
