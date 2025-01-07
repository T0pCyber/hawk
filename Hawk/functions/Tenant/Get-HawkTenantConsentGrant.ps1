Function Get-HawkTenantConsentGrant {
    <#
.SYNOPSIS
    Gathers application grants using Microsoft Graph

.DESCRIPTION
    Uses Microsoft Graph to gather information about application and delegate grants.
    Attempts to detect high risk grants for review. This function is used to identify
    potentially risky application permissions and consent grants in your tenant.

.EXAMPLE
    Get-HawkTenantConsentGrant
    Gathers and analyzes all OAuth grants in the tenant.

.OUTPUTS
    File: Consent_Grants.csv
    Path: \Tenant
    Description: Output of all consent grants with details about permissions and access

.NOTES
    This function requires the following Microsoft Graph permissions:
    - Application.Read.All
    - Directory.Read.All
#>
    [CmdletBinding()]
    param()

    Out-LogFile "Gathering OAuth / Application Grants" -Action

    Test-GraphConnection

    # Gather the grants using the internal Graph-based implementation
    [array]$Grants = Get-AzureADPSPermission -ShowProgress
    [bool]$flag = $false

    # Search the Grants for the listed bad grants that we can detect
    if ($Grants.ConsentType -contains 'AllPrincipals') {
        Out-LogFile "Found at least one 'AllPrincipals' Grant" -notice
        $flag = $true
    }
    if ([bool]($Grants.Permission -match 'all')) {
        Out-LogFile "Found at least one 'All' Grant" -notice
        $flag = $true
    }

    if ($flag) {
        Out-LogFile 'Review the information at the following link to understand these results' -Information
        Out-LogFile 'https://learn.microsoft.com/en-us/microsoft-365/security/office-365-security/detect-and-remediate-illicit-consent-grants' -Information
    }
    else {
        Out-LogFile "To review this data follow:" -Information
        Out-LogFile "https://learn.microsoft.com/en-us/microsoft-365/security/office-365-security/detect-and-remediate-illicit-consent-grants" -Information
    }

    $Grants | Out-MultipleFileType -FilePrefix "Consent_Grants" -csv -json
}