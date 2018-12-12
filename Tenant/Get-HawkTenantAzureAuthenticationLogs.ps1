# Return logon information from the Azure Audit logs
Function Get-HawkTenantAzureAuthenticationLogs {


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

    # Get our oauth token
    $oauth = Get-UserGraphAPIToken -AppIDURL "https://graph.windows.net"

    # Get the Oauth token Expiration time short 5 mintues
    $OauthExpiration =  (get-date ($oauth.ExpiresOn.UtcDateTime)).AddMinutes(-5)
    Out-Logfile ("Oauth Expiration Time: " + $OauthExpiration)

    # Tenant Domain
    $TenantDomain = ((get-msoldomain | Where-Object {$_.isinitial -eq $true}).name)

    # Pull the current date -30 days in the correct format (logs only go back 30 days)
    [string]$PastPeriod = "{0:s}" -f (get-date).AddDays(-30) + "Z"

    # Build the filter for pulling the data
    [string]$Filter = "`$filter=signinDateTime+ge+" + $PastPeriod
    $Url = "https://graph.windows.net/" + $TenantDomain + "/activities/signinEvents?api-version=beta&" + $filter

    Out-LogFile ("Collecting Azure AD Sign In reports for tenant " + $tenantdomain)
    Out-Logfile ("URL: " + $Url)

    # Build access header
    $Header = @{'Authorization' = "$($oauth.AccessTokenType) $($oauth.AccessToken)"}

    # Null out report and setup our counter
    $Report = $null
    $i = 0
    $BackoffCount = 0

    # Clear out any existing errors
    $error.clear()

    do {

        # Null out our raw report
        $RawReport = $null
        $Backoff = $false

        try {
            $RawReport = Invoke-WebRequest -UseBasicParsing -Headers $Header -Uri $url
            Out-LogFile $RawReport.StatusCode
        }
        catch {
            
            if ($RawReport.StatusCode -eq 503)
            {
                Out-LogFile "[WARNING] - Endpoint Overwhelmed Sleeping 5 min"
                Start-SleepwithProgress -sleeptime 300
                $Backoff = $true


            }
            if ($RawReport.StatusCode -eq 429)
            {
                Out-LogFile "[WARNING] - Backoff Requested"
                Out-LogFile $RawReport.Content
                Out-LogFile "Sleeping 5 minutes"
                Start-SleepWithProgress -sleeptime 300
                $Backoff = $true
            }
            else 
            {
                Out-LogFile "[ERROR] - Error retrieving report"
                $RawReport | Out-MultipleFileType -FilePrefix "Raw_Report" -xml
                Out-LogFile $Error
                break
            }
        }

        if ($Backoff)
        {
            # If we had to backoff then we just need to go thru and try again ... we should keep a backoff count
            if ($BackoffCount -gt 3)
            {
                Out-LogFile "[ERROR] - Backed off too many times"
                Write-Error "Backed off 3 times in a row stopping processing" -ErrorAction Stop
                break
            }
            
            # Increment the backoffcount
            $BackoffCount++
        }
        else
        {
            # Convert the report and then output it
            $Report += (ConvertFrom-Json -InputObject (($RawReport).content)).value

            # Reset our backoffcount
            $BackoffCount = 0

            # Get our next report url if we didn't get all of the data
            $Url = ($RawReport.Content | ConvertFrom-Json).'@odata.nextLink'
            Out-LogFile ("Next URL = " + $Url)

            $i++

            # We need to check for an expiring oauth token (could take some time to retrieve all data)
            # Don't need to check every time ... once per 10 is good
            if ($i % 10) {
                # If the current date is > expiration then we need to get a new token
                if ((get-date) -gt $OauthExpiration) {

                    $oauth = Get-UserGraphAPIToken -AppIDURL "https://graph.windows.net"
                    $Header = @{'Authorization' = "$($oauth.AccessTokenType) $($oauth.AccessToken)"}
                    $OauthExpiration = (get-date $oauth.ExpiresOn).AddMinutes(-5)
                }
            }
        }
        
    } while ($null -ne $Url)

    Out-LogFile ("Retrieved " + $Report.count + " Azure AD Sign In Entries")
    Out-MultipleFileType -FilePrefix Azure_Ad_signin -csv -Object $Report

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
}