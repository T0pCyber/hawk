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

    # Check if Hawk object exists and is fully initialized
    if (Test-HawkGlobalObject) {
        Initialize-HawkGlobalObject
    }

    Out-LogFile "Gathering OAuth / Application Grants" -Action

    Test-GraphConnection

    # Gather the grants using the internal Graph-based implementation
    [array]$Grants = Get-AzureADPSPermission -ShowProgress
    
    # Create new Property for Consent_Grants output table
    $Grants | Add-Member -NotePropertyName ConsentGrantRiskCategory -NotePropertyValue ""
    
    [bool]$flag = $false

    # Define list of Extremely Dangerous grants
    [array]$ExtremelyDangerousGrants = "^AppRoleAssignment\.ReadWrite\.All$", "^RoleManagement\.ReadWrite\.Directory$"

    # Define list of High Risk grants
    [array]$HighRiskGrants = "^BitlockerKey\.Read\.All$", "^Chat\.", "^Directory\.ReadWrite\.All$", "^eDiscovery\.", 
        "^Files\.", "^MailboxSettings\.ReadWrite$", "^Mail\.ReadWrite$", "^Mail\.Send$", "^Sites\.", "^User\."

    # Search the Grants for the listed bad grants that we can detect

    #Flag broad-scope grants
    [int]$BroadGrantCount = 0
    $Grants | ForEach-Object -Process {
        if($_.ConsentType -contains 'AllPrincipals' -or $_.Permission -match 'all') {
            $_.ConsentGrantRiskCategory = "Broad-Scope Grant"
            $BroadGrantCount += 1
        }
    }

    if($BroadGrantCount -gt 0) {
        Out-LogFile "Found $BroadGrantCount broad-scoped grants ('AllPrincipals' or '*.All')" -notice
        $flag = $true
    }
    
    #Flag Extremely Dangerous grants; if a grant is both broad-scope and E.D., flag as E.D.
    [int]$EDGrantCount = 0
    foreach($grant in $ExtremelyDangerousGrants) {
        $Grants | ForEach-Object -Process {
            if($_.Permission -match $grant){
                $_.ConsentGrantRiskCategory = "Extremely Dangerous"
                $EDGrantCount += 1
            }
        }
    }

    if ($EDGrantCount -gt 0) {
        Out-LogFile "Found $EDGrantCount Extremely Dangerous Grant(s)" -notice
        $flag = $true
    }
    
    #Flag High Risk grants; if a grant is both broad-scope and H.R., flag as H.R.
    [int]$HRGrantCount = 0
    foreach($grant in $HighRiskGrants) {
        $Grants | ForEach-Object -Process {
            if($_.Permission -match $grant){
                $_.ConsentGrantRiskCategory = "High Risk"
                $HRGrantCount += 1
            }
        }
    }

    if ($HRGrantCount -gt 0) {
        Out-LogFile "Found $HRGrantCount High Risk Grant(s)" -notice
        $flag = $true
    }

    if ($flag) {
        Out-LogFile "Please verify these grants are legitimate / required." -Notice
        Out-LogFile 'For more information on understanding these results results, visit' -Notice
        Out-LogFile 'https://learn.microsoft.com/en-us/microsoft-365/security/office-365-security/detect-and-remediate-illicit-consent-grants' -Notice
        
        # Create investigation file for concerning grants
        $grantsForInvestigation = $Grants | Where-Object { $_.ConsentGrantRiskCategory -ne "" }
        $grantsForInvestigation | Out-MultipleFileType -FilePrefix "_Investigate_Consent_Grants" -csv -json -Notice
    }
    else {
        Out-LogFile "To review this data follow:" -Information
        Out-LogFile "https://learn.microsoft.com/en-us/microsoft-365/security/office-365-security/detect-and-remediate-illicit-consent-grants" -Information
    }

    # Output all grants
    $Grants | Out-MultipleFileType -FilePrefix "Consent_Grants" -csv -json
}