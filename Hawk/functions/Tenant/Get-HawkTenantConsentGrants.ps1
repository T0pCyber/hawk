Function Get-HawkTenantConsentGrant {
    <#
    .SYNOPSIS
        Gathers application grants
    .DESCRIPTION
        Uses Microsoft Graph to gather information about application and delegate grants.
        Attempts to detect high risk grants for review.
    .OUTPUTS
        File: Consent_Grants.csv
        Path: \Tenant
        Description: Output of all consent grants
    .EXAMPLE
        Get-HawkTenantConsentGrant
        Gathers Grants
    #>
        [CmdletBinding()]
        param()

        Out-LogFile "Gathering OAuth / Application Grants"

        Test-GraphConnection
        Send-AIEvent -Event "CmdRun"

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
            Out-LogFile 'Review the information at the following link to understand these results' -notice
            Out-LogFile 'https://learn.microsoft.com/en-us/microsoft-365/security/office-365-security/detect-and-remediate-illicit-consent-grants' -notice
        }
        else {
            Out-LogFile "To review this data follow:"
            Out-LogFile "https://learn.microsoft.com/en-us/microsoft-365/security/office-365-security/detect-and-remediate-illicit-consent-grants"
        }

        $Grants | Out-MultipleFileType -FilePrefix "Consent_Grants" -csv -json
    }