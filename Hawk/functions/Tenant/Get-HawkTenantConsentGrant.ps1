﻿Function Get-HawkTenantConsentGrant {
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

    Out-LogFile "Gathering OAuth / Application Grants"

    Test-GraphConnection

    # Gather the grants using the internal Graph-based implementation
    [array]$Grants = Get-AzureADPSPermission -ShowProgress
    
    # Create new Property for Consent_Grants output table
    $Grants | Add-Member -NotePropertyName Flag -NotePropertyValue ""
    
    [bool]$flag = $false

    # Define list of Extremely Dangerous grants
    [array]$ExtremelyDangerousGrants = "AppRoleAssignment.ReadWrite.All", "RoleManagementAlert.ReadWrite.Directory"

    # Define list of High Risk grants
    [array]$HighRiskGrants = "BitlockerKey.Read.All", "Chat.*", "Directory.ReadWrite.All", "eDiscovery.*", "Files.*", 
                            "MailboxSettings.ReadWrite", "Mail.ReadWrite", "Mail.Send", "Sites.*", "User.*"

    # Search the Grants for the listed bad grants that we can detect
    #Flag broad-scope grants
    foreach($grant in $Grants) {
        $Grants | ForEach-Object -Process {
            if($_.ConsentType -contains 'AllPrincipals' -or $_.Permission -match 'all') {
                $_.Flag = "Broad-Scope Grant"
            }
        }
    }

    if ($Grants.ConsentType -contains 'AllPrincipals') {
        Out-LogFile "Found at least one 'AllPrincipals' Grant" -notice
        $flag = $true
    }

	if ([bool]($Grants.Permission -match 'all')) {
        Out-LogFile "Found at least one 'All' Grant" -notice
        $flag = $true
    }
    
    #Flag Extremely Dangerous grants; if a grant is both broad-scope and E.D., flag as E.D.
    [int]$EDGrantCount = 0
    foreach($grant in $ExtremelyDangerousGrants) {
        $Grants | ForEach-Object -Process {
            if($_.Permission -cmatch $grant){
                $_.Flag = "Extremely Dangerous"
                $EDGrantCount += 1
            }
        }
    }

    if ($EDGrantCount -gt 0) {
        Out-LogFile "Found at least one Extremely Dangerous Grant" -notice
        $flag = $true
    }
    
    #Flag High Risk grants; if a grant is both broad-scope and H.R., flag as H.R.
    [int]$HRGrantCount = 0
    foreach($grant in $HighRiskGrants) {
        $Grants | ForEach-Object -Process {
            if($_.Permission -cmatch $grant){
                $_.Flag = "High Risk"
                $HRGrantCount += 1
            }
        }
    }

    if ($HRGrantCount -gt 0) {
        Out-LogFile "Found at least one High Risk Grant" -notice
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