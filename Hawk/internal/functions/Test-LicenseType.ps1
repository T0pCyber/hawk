function Test-LicenseType {
    <#
    .SYNOPSIS
        Identifies the Microsoft 365 license type (E5/G5, E3/G3, or other) for the current tenant and returns both the license type and corresponding retention period.

    .DESCRIPTION
        This function retrieves the list of subscribed SKUs for the tenant using the Microsoft Graph API. It determines the license type based on the `SkuPartNumber` and returns both the license type and appropriate audit log retention period:
        - E5/G5 licenses (including equivalents): 365 days retention
        - E3/G3 licenses (including equivalents): 180 days retention  
        - Other/Unknown licenses: 90 days retention

    .EXAMPLE
        PS> Test-LicenseType
        
        LicenseType RetentionPeriod
        ----------- ---------------
        E5          365

        Returns E5 license type and 365 days retention period.

    .EXAMPLE
        PS> Test-LicenseType 
        
        LicenseType RetentionPeriod
        ----------- ---------------
        G3          180

        Returns G3 license type and 180 days retention period.
    
    .EXAMPLE 
        PS> Test-LicenseType
        
        LicenseType RetentionPeriod
        ----------- ---------------
        Unknown     90

        Returns Unknown license type and default 90 days retention period.

    .NOTES
        Author: Jonathan Butler
        Last Updated: January 18, 2025

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

        # Check for E5/G5 or equivalent license
        if ($subscriptions.SkuPartNumber -match 'ENTERPRISEPREMIUM|SPE_E5|DEVELOPERPACK_E5|M365_E5|SPE_G5|ENTERPRISEPREMIUM_GOV|M365_G5|MICROSOFT365_G5') {
            $licenseInfo.LicenseType = if ($subscriptions.SkuPartNumber -match '_G5|_GOV') { 'G5' } else { 'E5' }
            $licenseInfo.RetentionPeriod = 365
            return $licenseInfo
        }

        # Check for E3/G3 or equivalent license
        if ($subscriptions.SkuPartNumber -match 'ENTERPRISEPACK|M365_E3|DEVELOPERPACK_E3|SPE_G3|ENTERPRISEPACK_GOV|M365_G3|MICROSOFT365_G3') {
            $licenseInfo.LicenseType = if ($subscriptions.SkuPartNumber -match '_G3|_GOV') { 'G3' } else { 'E3' }
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