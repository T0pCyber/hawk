# Return logon information from the Azure Audit logs
Function Get-HawkTenantAzureAuthenticationLogs {

    <#

	.SYNOPSIS
	Retrieves Azure AD Sign in Logs

	.DESCRIPTION
    Uses Graph API to retrieve Azure AD Signin Logs
    ** Requires that the tenant have an Azure AD P1 or P2 license or trial license

	.OUTPUTS

	File: Azure_AD_Signin.csv
	Path: \
	Description: Azure AD Signin Report

    .EXAMPLE
	Get-HawkTenantAzureAuthenticationLogs

	Returns all Azure AD Signin reports in CSV format

	#>


    # Make sure we have a connection to MSOL since we will need it
    Test-MSOLConnection

    # Need to setup the hawk global object explicitly here instead of relying on out-logfile to do it
    Initialize-HawkGlobalObject
    Send-AIEvent -Event "CmdRun"

    # Make sure we have the needed license to access this report
    if ([bool]$hawk.AdvancedAzureLicense) {
        Out-LogFile "Verified that we can pull Azure AD Sign In Logs"
    }
    else {
        Out-LogFile "[ERROR] - No Azure AD Premium P1 or P2 license found on tenant"
        Write-Error -Message "Azure AD Premium P1 or P2 license required to access Azure AD Sign In Events" -ErrorAction Stop
        break
    }

    # Tenant Domain
    $TenantDomain = ((Get-MsolDomain | Where-Object { $_.isinitial -eq $true }).name)

    # Pull the current date -30 days in the correct format (logs only go back 30 days)
    [string]$PastPeriod = "{0:s}" -f (Get-Date).AddDays(-30) + "Z"

    # Build the filter for pulling the data
    [string]$Filter = "`$filter=signinDateTime+ge+" + $PastPeriod
    $Url = "https://graph.windows.net/" + $TenantDomain + "/activities/signinEvents?api-version=beta&" + $filter

    Out-LogFile ("Collecting Azure AD Sign In reports for tenant " + $tenantdomain)
    Out-Logfile ("URL: " + $Url)

    # Build access header
    $Header = Connect-AzureGraph

    # Null out report and setup our counter
    $Report = $null
    $i = 0
    [int]$BackoffCount = 1

    # Clear out any existing errors
    $error.clear()

    do {

        # Null out our raw report
        $RawReport = $null
        $Backoff = $false

        try {
            $RawReport = Invoke-WebRequest -UseBasicParsing -Headers $Header -Uri $url -TimeoutSec 300
            # Out-LogFile $RawReport.StatusCode
        }
        catch {

            Out-LogFile "Catch"
            Out-LogFile "Error:"
            Out-LogFile $_
            Out-LogFile ("Status Code:" + $RawReport.StatusCode)
            $RawReport | Export-Clixml C:\raw_report.xml
            
            # If status code is 503 then we had too many requests
            if ($RawReport.StatusCode -eq 503) {
                Out-LogFile "[WARNING] - Endpoint Overwhelmed Sleeping 5 min"
                Start-SleepwithProgress -sleeptime 300
                $Backoff = $true
            }
            # if status code is 429 we got an explicit backoff from the service
            elseif ($RawReport.StatusCode -eq 429) {
                Out-LogFile "[WARNING] - Backoff Requested"
                Out-LogFile $RawReport.Content
                Out-LogFile "Sleeping 5 minutes"
                Start-SleepWithProgress -sleeptime 300
                $Backoff = $true
            }
            # If the RawReport is just empty then something went wrong and we should retry
            elseif ($null -eq $RawReport) {
                Out-LogFile "[WARNING] - No Data Returned"
                Start-SleepWithProgress -sleeptime (300 * $BackoffCount)
                $Backoff = $true                
            }

            # In all other cases we are going to bail
            else {
                Out-LogFile "[ERROR] - Error retrieving report"
                $RawReport | Out-MultipleFileType -FilePrefix "Raw_Report" -xml
                Out-LogFile $_
                break
            }
        }

        if ($Backoff) {
            # If we had to backoff then we just need to go thru and try again ... we should keep a backoff count
            if ([int]$BackoffCount -gt 3) {
                Out-LogFile "[ERROR] - Backed off too many times"
                Out-LogFile $error
                Write-Error "Backed off 3 times in a row stopping processing" -ErrorAction Stop
                break
            }
            else {
                # Increment the backoffcount
                [int]$BackoffCount++
                Out-LogFile ("BackoffCount: " + $BackoffCount)
            }            
        }
        else {

            # Make sure the report is set to $null
            $Report = $Null

            # Convert the report and then output it
            $Report = (ConvertFrom-Json -InputObject (($RawReport).content)).value

            # Reset our backoffcount
            $BackoffCount = 1

            # Get our next report url if we didn't get all of the data
            $Url = ($RawReport.Content | ConvertFrom-Json).'@odata.nextLink'
            Out-LogFile ("Next URL = " + $Url)

            $i++

            # We need to check for an expiring oauth token (could take some time to retrieve all data)
            # Don't need to check every time ... once per 10 is good
            if ($i % 10) { $Header = Connect-AzureGraph }
        }

        # Out-LogFile ("Retrieved " + $Report.count + " Azure AD Sign In Entries")
        Out-MultipleFileType -FilePrefix Azure_Ad_signin -csv -Object $Report -append
    }
    while ($null -ne $Url)
}