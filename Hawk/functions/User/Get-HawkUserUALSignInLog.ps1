Function Get-HawkUserUALSignInLog {
<#
.SYNOPSIS
    Gathers ip addresses that logged into the user account
.DESCRIPTION
    Pulls AzureActiveDirectoryAccountLogon events from the unified audit log for the provided user.

    If used with -ResolveIPLocations:
    Attempts to resolve the IP location using freegeoip.net
    Will flag ip addresses that are known to be owned by Microsoft using the XML from:
    https://support.office.com/en-us/article/URLs-and-IP-address-ranges-for-Office-365-operated-by-21Vianet-5C47C07D-F9B6-4B78-A329-BFDC1B6DA7A0
.PARAMETER UserPrincipalName
    Single UPN of a user, comma seperated list of UPNs, or array of objects that contain UPNs.
.PARAMETER ResolveIPLocations
    Resolved IP Locations
.OUTPUTS

    File: Converted_Authentication_Logs.csv
    Path: \<User>
    Description: All authentication activity for the user in a more readable form
.EXAMPLE

    Get-HawkUserUALSignInLog -UserPrincipalName user@contoso.com -ResolveIPLocations

    Gathers authentication information for user@contoso.com.
    Attempts to resolve the IP locations for all authentication IPs found.
.EXAMPLE

    Get-HawkUserUALSignInLog -UserPrincipalName (get-mailbox -Filter {Customattribute1 -eq "C-level"}) -ResolveIPLocations

    Gathers authentication information for all users that have "C-Level" set in CustomAttribute1
    Attempts to resolve the IP locations for all authentication IPs found.
#>
    param (
        [Parameter(Mandatory = $true)]
        [array]$UserPrincipalName
    )

    BEGIN {
        if (Test-HawkGlobalObject) {
            Initialize-HawkGlobalObject
        }

        Out-LogFile "Gathering Microsoft Entra ID Sign-in Logs" -Action
        Test-GraphConnection
        Send-AIEvent -Event "CmdRun"
        [array]$UserArray = Test-UserObject -ToTest $UserPrincipalName
        
        # Track overall success
        $global:processSuccess = $true

        # Configure timeout settings - increase from default 100 seconds to 600 seconds
        $originalTimeout = [System.Threading.Timeout]::Infinite
        [Microsoft.Graph.PowerShell.Runtime.RuntimeHandler]::SetDefaultConfiguration((New-GraphRequestConfiguration -Timeout 600000))
    }

    PROCESS {
        foreach ($Object in $UserArray) {
            [string]$User = $Object.UserPrincipalName
            
            try {
                Out-LogFile ("Retrieving sign-in logs for " + $User) -Action

                # Create date filter using Hawk dates
                $startDateUtc = $Hawk.StartDate.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
                $endDateUtc = $Hawk.EndDate.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
                
                # Combine user and date filters
                $filter = "userPrincipalName eq '$User' and createdDateTime ge $startDateUtc and createdDateTime le $endDateUtc"

                # Initialize collection for all sign-in logs
                $allSignInLogs = [System.Collections.ArrayList]@()
                
                try {
                    # Get initial page with smaller page size
                    $params = @{
                        Filter = $filter
                        PageSize = 50  # Smaller page size to avoid timeouts
                        All = $false   # Handle pagination manually
                    }

                    do {
                        $currentBatch = Get-MgAuditLogSignIn @params
                        
                        if ($currentBatch) {
                            $allSignInLogs.AddRange($currentBatch)
                            
                            # Update progress
                            Write-Progress -Activity "Retrieving Entra Sign-in Logs" `
                                -Status "Retrieved $($allSignInLogs.Count) logs" `
                                -PercentComplete -1
                        }

                        # Get next page link if available
                        $params = @{}
                        if ($currentBatch.'@odata.nextLink') {
                            $params['Next'] = $true
                        }
                    } while ($params.Count -gt 0 -and $currentBatch.'@odata.nextLink')

                } catch {
                    Out-LogFile ("Error during pagination for $User : " + $_.Exception.Message) -isError
                    throw  # Re-throw to be caught by outer try-catch
                }

                Write-Progress -Activity "Retrieving Entra Sign-in Logs" -Completed

                if ($allSignInLogs.Count -gt 0) {
                    Out-LogFile ("Retrieved " + $allSignInLogs.Count + " sign-in log entries for " + $User) -Information

                    # Write all logs to CSV/JSON
                    $allSignInLogs | Out-MultipleFileType -FilePrefix "EntraSignInLog_$User" -User $User -csv -json

                    # Check for risky sign-ins
                    $riskySignIns = $allSignInLogs | Where-Object {
                        $_.RiskLevelDuringSignIn -in @('high', 'medium', 'low') -or
                        $_.RiskLevelAggregated -in @('high', 'medium', 'low')
                    }

                    if ($riskySignIns.Count -gt 0) {
                        # Flag for investigation
                        Out-LogFile ("Found " + $riskySignIns.Count + " risky sign-ins for " + $User) -notice
                        
                        # Group and report risk levels
                        $duringSignIn = $riskySignIns | Group-Object -Property RiskLevelDuringSignIn | 
                            Where-Object {$_.Name -in @('high', 'medium', 'low')}
                        foreach ($risk in $duringSignIn) {
                            Out-LogFile ("Found " + $risk.Count + " sign-ins with risk level during sign-in: " + $risk.Name) -silentnotice
                        }

                        $aggregated = $riskySignIns | Group-Object -Property RiskLevelAggregated | 
                            Where-Object {$_.Name -in @('high', 'medium', 'low')}
                        foreach ($risk in $aggregated) {
                            Out-LogFile ("Found " + $risk.Count + " sign-ins with aggregated risk level: " + $risk.Name) -silentnotice
                        }

                        Out-LogFile ("Review SignInLog.csv/json in the " + $User + " folder for complete details") -silentnotice
                    }
                }
                else {
                    Out-LogFile ("No sign-in logs found for " + $User + " in the specified time period") -Information
                }
            }
            catch {
                $global:processSuccess = $false
                Out-LogFile ("Error retrieving sign-in logs for " + $User + " : " + $_.Exception.Message) -isError
                Write-Error -ErrorRecord $_ -ErrorAction Continue
            }
        }
    }

    END {
        # Reset timeout to original value
        [Microsoft.Graph.PowerShell.Runtime.RuntimeHandler]::SetDefaultConfiguration((New-GraphRequestConfiguration -Timeout $originalTimeout))

        # Only show completion message if successful
        if ($global:processSuccess) {
            Out-LogFile "Completed exporting Entra sign-in logs" -Information
        }
        Remove-Variable -Name processSuccess -Scope Global -ErrorAction SilentlyContinue
    }
}