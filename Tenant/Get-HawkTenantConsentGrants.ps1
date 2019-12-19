Function Get-HawkTenantConsentGrants {
    
    <#
 
	.SYNOPSIS
	Gathers application grants

	.DESCRIPTION
    Used the script from https://docs.microsoft.com/en-us/microsoft-365/security/office-365-security/detect-and-remediate-illicit-consent-grants to gather information about
    application and delegate grants.  Attempts to detect high risk grants for review.

	.OUTPUTS
	File: Consent_Grants.csv
	Path: \Tenant
	Description: Output of all consent grants

	.EXAMPLE
	Get-HawkTenantConsentGrants
	
	Gathers Grants

    #>
    
    Out-LogFile "Gathering Oauth / Application Grants"

    Test-AzureADConnection
    Send-AIEvent -Event "CmdRun"

    # Gather the grants
    # Using the script from the article https://docs.microsoft.com/en-us/microsoft-365/security/office-365-security/detect-and-remediate-illicit-consent-grants
    [array]$Grants = Get-AzureADPSPermissions -ShowProgress
    [bool]$flag = $false

    # Search the Grants for the listed bad grants that we can detect
    if ($Grants.consenttype -contains 'AllPrinciples') {
        Out-LogFile "Found at least one `'AllPrinciples`' Grant" -notice
        $flag = $true
    }
    if ([bool]($Grants.permission -match 'all')){
        Out-LogFile "Found at least one `'All`' Grant" -notice
        $flag = $true
    }

    if ($flag){
        Out-LogFile 'Review the information at the following link to understand these results' -notice
        Out-LogFile 'https://docs.microsoft.com/en-us/microsoft-365/security/office-365-security/detect-and-remediate-illicit-consent-grants#inventory-apps-with-access-in-your-organization' -notice
    }
    else {
        Out-LogFile "To review this data follow:"
        Out-LogFile "https://docs.microsoft.com/en-us/microsoft-365/security/office-365-security/detect-and-remediate-illicit-consent-grants#inventory-apps-with-access-in-your-organization"
    }

    $Grants | Out-MultipleFileType -FilePrefix "Consent_Grants" -csv
}