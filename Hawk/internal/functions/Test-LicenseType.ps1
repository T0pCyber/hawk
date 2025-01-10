function Test-LicenseType {
    <#
    .SYNOPSIS
        Identifies the Microsoft 365 license type (E5, E3, or other) for the current tenant and returns both the license type and corresponding retention period.

    .DESCRIPTION
        This function retrieves the list of subscribed SKUs for the tenant using the Microsoft Graph API. It determines the license type based on the `SkuPartNumber` and returns both the license type and appropriate audit log retention period:
        - E5 licenses (including equivalents like Developer Pack E5): 365 days retention
        - E3 licenses (including equivalents like Developer Pack E3): 180 days retention  
        - Other/Unknown licenses: 90 days retention

    .EXAMPLE
        PS> Test-HawkLicenseType
        
        LicenseType RetentionPeriod
        ----------- ---------------
        E5          365

        Returns E5 license type and 365 days retention period.

    .EXAMPLE
        PS> Test-HawkLicenseType 
        
        LicenseType RetentionPeriod
        ----------- ---------------
        E3          180

        Returns E3 license type and 180 days retention period.
    
    .EXAMPLE 
        PS> Test-HawkLicenseType
        
        LicenseType RetentionPeriod
        ----------- ---------------
        Unknown     90

        Returns Unknown license type and default 90 days retention period.

    .NOTES
        Author: Jonathan Butler
        Last Updated: January 9, 2025

    .LINK
        https://learn.microsoft.com/en-us/powershell/microsoftgraph
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    try {
        # Get tenant subscriptions
        $subscriptions = Get-MgSubscribedSku

        # Create custom object to store both license type and retention period
        $licenseInfo = [PSCustomObject]@{
            LicenseType = 'Unknown'
            RetentionPeriod = 90
        }

        # Check for E5 or equivalent license
        if ($subscriptions.SkuPartNumber -match 'ENTERPRISEPREMIUM|SPE_E5|DEVELOPERPACK_E5|M365_E5') {
            $licenseInfo.LicenseType = 'E5'
            $licenseInfo.RetentionPeriod = 365
            return $licenseInfo
        }

        # Check for E3 or equivalent license
        if ($subscriptions.SkuPartNumber -match 'ENTERPRISEPACK|M365_E3|DEVELOPERPACK_E3') {
            $licenseInfo.LicenseType = 'E3'
            $licenseInfo.RetentionPeriod = 180
            return $licenseInfo
        }

        # Return default values for unknown license type
        return $licenseInfo
    }
    catch {
        Out-LogFile "Unable to determine license type. Defaulting to 90 days retention." -information
        return [PSCustomObject]@{
            LicenseType = 'Unknown'
            RetentionPeriod = 90
        }
    }
}