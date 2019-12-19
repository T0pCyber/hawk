# Retrives a list of all applciations that have the ability to access user data
# There are Azure AD Cmdlets for these
# https://github.com/OfficeDev/O365-InvestigationTooling/blob/master/AzureAppEnumerationViaGraph.ps1
Function Get-HawkTenantOauthConsentGrants {
    
    <#
 
	.SYNOPSIS
	Gathers application Oauth grants

	.DESCRIPTION
	Gathers Application Oauth grants along with their display names.  The grants listed are applications
	that have been granted access to various data inside the tenant.  The scope field outlines
	what data a given application has access to.

	.OUTPUTS
	File: AzureADOauthGrants.csv
	Path: \
	Description: Output of all grants as CSV.

	File: AzureADOauthGrants.txt
	Path: \
	Description: Output of all grants as txt
		
	.EXAMPLE
	Get-HawkTenantOauthConsentGrants
	
	Gathers all Oauth Grants

    #>
    
    Out-LogFile "Gathering Oauth Consent Grants"

    Test-AzureADConnection
    Send-AIEvent -Event "CmdRun"

    # Next up gather the consent grants using the azureadcommand
    [array]$Grant = Get-AzureADOauth2PermissionGrant -all:$true

    # Check if we have a return
    if ($null -eq $Grant) {
        Out-LogFile "No Grants Found."
    }
    # If we do then we need to pull some addtional information then output
    else {
        Out-LogFile ("Found " + $Grant.count + " OAuth Grants")
        Out-LogFile "Processing Grants"

        # Add in the display name information
        $FullGrantInfo = $Grant | Select-Object -Property *, @{Name = "DisplayName"; Expression = { (Get-AzureADServicePrincipal -ObjectId $_.clientid).displayname } }

        # Push our data out to a file
        Out-MultipleFileType -Object $FullGrantInfo -FilePrefix AzureADOauthGrants -csv

    }

}