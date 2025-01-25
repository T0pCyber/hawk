function Test-EntraWorkloadIDPremium {
    <#
    .SYNOPSIS
        Checks if the tenant has the required Entra Workload ID Premium license.
    
    .DESCRIPTION
        Tests whether the tenant has any SKUs that would include Entra Workload ID Premium
        capabilities. This includes standalone licenses and bundles like Microsoft 365 E5.
        
        The function checks for the following license types:
        - AAD_PREMIUM_P2 (Standalone AAD Premium P2)
        - ENTERPRISEPREMIUM (Microsoft 365 E5)
        - SPE_E5 (Microsoft 365 E5)
        - IDENTITY_THREAT_PROTECTION (Microsoft 365 E5 Security)
    
    .EXAMPLE
        $result = Test-EntraWorkloadIDPremium
        if ($result.HasLicense) {
            Write-Output "Found licenses: $($result.LicenseDetails)"
        }
        else {
            Write-Warning "No premium licenses found"
        }
        
        Checks for Entra Workload ID Premium licenses and displays details if found.
        The example shows how to handle both success and failure cases.

    .EXAMPLE
        # Within a function needing premium features
        $licenseCheck = Test-EntraWorkloadIDPremium
        if (-not $licenseCheck.HasLicense) {
            Out-LogFile $licenseCheck.LicenseDetails -isWarning
            return
        }
        
        Shows how to use the function to validate license requirements before 
        attempting premium operations. The example demonstrates early exit pattern 
        when required licenses are not found.
    
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