function Test-HawkLicenseType {
    <#
    .SYNOPSIS
        Identifies the Microsoft 365 license type (E5, E3, or other) for the current tenant and returns the corresponding retention period.

    .DESCRIPTION
        This function retrieves the list of subscribed SKUs for the tenant using the Microsoft Graph API. It determines the license type based on the `SkuPartNumber` to return the appropriate audit log retention period:
        - 365 days for E5 licenses (including equivalents like Developer Pack E5)
        - 180 days for E3 licenses (including equivalents like Developer Pack E3)  
        - 90 days as a default retention period if no matching license is found

    .EXAMPLE
        PS> Test-HawkLicenseType
        365
        
        Returns 365 days retention period because the tenant has an E5 license.

    .EXAMPLE
        PS> Test-HawkLicenseType 
        180
        
        Returns 180 days retention period because the tenant has an E3 license.
    
    .EXAMPLE 
        PS> Test-HawkLicenseType
        90
        
        Returns default 90 days retention period because tenant license type could not be determined.

    .NOTES
        Author: Jonathan Butler
        Last Updated: January 9, 2025

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
        Out-LogFile "Unable to determine license type. Defaulting to 90 days retention." -information
        return 90
    }
}