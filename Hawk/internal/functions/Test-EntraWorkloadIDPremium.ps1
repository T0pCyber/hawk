function Test-EntraWorkloadIDPremium {
    <#
    .SYNOPSIS
        Checks if the tenant has the required Entra Workload ID Premium license.
    
    .DESCRIPTION
        Tests whether the tenant has any SKUs that would include Entra Workload ID Premium
        capabilities. This includes standalone licenses and bundles like Microsoft 365 E5.
    
    .OUTPUTS
        [PSCustomObject] with properties:
        - HasLicense: Boolean indicating if required license exists
        - LicenseDetails: String with details about found licenses
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param()

    $requiredSkus = @(
        'AAD_PREMIUM_P2',          # Standalone AAD Premium P2
        'ENTERPRISEPREMIUM',       # Microsoft 365 E5
        'SPE_E5',                  # Microsoft 365 E5
        'IDENTITY_THREAT_PROTECTION' # Microsoft 365 E5 Security
    )

    $foundLicenses = Get-MgSubscribedSku | Where-Object { 
        $_.SkuPartNumber -in $requiredSkus -and
        $_.PrepaidUnits.Enabled -gt 0 
    }

    if ($foundLicenses) {
        $licenseDetails = $foundLicenses | ForEach-Object {
            "$($_.SkuPartNumber) (Enabled: $($_.PrepaidUnits.Enabled), Used: $($_.ConsumedUnits))"
        }

        [PSCustomObject]@{
            HasLicense = $true
            LicenseDetails = $licenseDetails -join "; "
        }
    }
    else {
        [PSCustomObject]@{
            HasLicense = $false
            LicenseDetails = "No Entra Workload ID Premium capable licenses found. Required licenses: $($requiredSkus -join ', ')"
        }
    }
}