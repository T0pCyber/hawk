Function Get-HawkUserEntraIDSignInLog {
    <#
    .SYNOPSIS
        Retrieves Microsoft Entra ID sign-in logs for specified users from the most recent 14 days.
    
    .DESCRIPTION
        This function retrieves sign-in logs from Microsoft Entra ID (formerly Azure AD) for specified users.
        Due to Microsoft Graph API limitations, this function can only retrieve logs from the past 14 days
        or less. If you specify a longer time range, the function will automatically use only the most 
        recent 14 days of data from your specified end date.
    
        The function analyzes sign-in patterns to identify:
        - Risky sign-ins based on Microsoft's detection
        - Both real-time and aggregated risk levels
        - Risk level distributions and trends
    
    .PARAMETER UserPrincipalName
        Specifies which users to investigate. Accepts:
        - Single user: "user@contoso.com"
        - Multiple users: @("user1@contoso.com", "user2@contoso.com")
        - Object array: (Get-Mailbox -Filter {CustomAttribute1 -eq "VIP"})
    
    .OUTPUTS
        Creates the following files in the user's output directory:
        - EntraSignInLog_[user].csv - All sign-in data in CSV format
        - EntraSignInLog_[user].json - All sign-in data in JSON format
    
        Note: Only contains data from the most recent 14 days relative to the specified end date.
    
    .EXAMPLE
        Get-HawkUserEntraIDSignInLog -UserPrincipalName "user@contoso.com"
    
        Gets the most recent 14 days of sign-in logs for user@contoso.com.
    
    .EXAMPLE
        Get-HawkUserEntraIDSignInLog -UserPrincipalName (Get-Mailbox -Filter {CustomAttribute1 -eq "VIP"})
    
        Gets the most recent 14 days of sign-in logs for all VIP users.
    
    .NOTES
        Due to Microsoft Graph API limitations:
        - Can only retrieve up to 14 days of historical data
        - Longer date ranges will be automatically adjusted
        - Data outside the 14-day window is not available through this API
    #>
    [CmdletBinding()]
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

        # Calculate date range - limit to 2 weeks from end date
        $endDateUtc = $Hawk.EndDate.ToUniversalTime()
        $twoWeeksAgo = $endDateUtc.AddDays(-14)
        $requestedStart = $Hawk.StartDate.ToUniversalTime()
        
        # Compare dates manually since PowerShell doesn't have DateTime.Max
        $effectiveStartDate = if ($requestedStart -gt $twoWeeksAgo) {
            $requestedStart
        } else {
            $twoWeeksAgo
        }

        # Notify user about 14-day limit and any date adjustment
        Out-LogFile "Hawk Entra ID Sign-in logs is limited to the most recent 14 days" -Information
        
        if ($Hawk.StartDate.ToUniversalTime() -lt $twoWeeksAgo) {
            Out-LogFile "Your requested date range exceeds this limit. Data will only be available from $($effectiveStartDate.ToString('yyyy-MM-dd')) to $($endDateUtc.ToString('yyyy-MM-dd'))" -Information
        } else {
            Out-LogFile "Retrieving data from $($effectiveStartDate.ToString('yyyy-MM-dd')) to $($endDateUtc.ToString('yyyy-MM-dd'))" -Information
        }
    }

    PROCESS {
        foreach ($Object in $UserArray) {
            [string]$User = $Object.UserPrincipalName
            
            try {
                Out-LogFile ("Retrieving sign-in logs for " + $User) -Action

                # Use adjusted date range and ensure we have valid dates
                $startDateUtc = if ($effectiveStartDate) {
                    $effectiveStartDate.ToString('yyyy-MM-ddTHH:mm:ssZ')
                } else {
                    $twoWeeksAgo.ToString('yyyy-MM-ddTHH:mm:ssZ')
                }
                
                $endDateUtc = $Hawk.EndDate.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
                
                # Combine user and date filters
                $filter = "userPrincipalName eq '$User' and createdDateTime ge $startDateUtc and createdDateTime le $endDateUtc"
                
                $processedCount = 0
                $signInLogs = Get-MgAuditLogSignIn -Filter $filter -All -ErrorAction Stop

                foreach ($log in $signInLogs) {
                    $processedCount++
                    if ($processedCount % 100 -eq 0) {
                        Write-Progress -Activity "Retrieving Entra Sign-in Logs" `
                            -Status "Processed $processedCount logs" `
                            -PercentComplete -1
                    }
                }

                Write-Progress -Activity "Retrieving Entra Sign-in Logs" -Completed

                if ($signInLogs.Count -gt 0) {
                    Out-LogFile ("Retrieved " + $signInLogs.Count + " sign-in log entries for " + $User) -Information

                    # Write all logs to CSV/JSON
                    $signInLogs | Out-MultipleFileType -FilePrefix "EntraSignInLog_$User" -User $User -csv -json

                    # Check for risky sign-ins
                    $riskySignIns = $signInLogs | Where-Object {
                        $_.RiskLevelDuringSignIn -in @('high', 'medium') -or
                        $_.RiskLevelAggregated -in @('high', 'medium')
                    }

                    if ($riskySignIns.Count -gt 0) {
                        # Flag for investigation
                        Out-LogFile ("Found " + $riskySignIns.Count + " risky sign-ins for " + $User) -notice
                        
                        # Group and report risk levels
                        $duringSignIn = $riskySignIns | Group-Object -Property RiskLevelDuringSignIn | 
                            Where-Object {$_.Name -in @('high', 'medium')}
                        foreach ($risk in $duringSignIn) {
                            Out-LogFile ("Found " + $risk.Count + " sign-ins with risk level during sign-in: " + $risk.Name) -silentnotice
                        }

                        $aggregated = $riskySignIns | Group-Object -Property RiskLevelAggregated | 
                            Where-Object {$_.Name -in @('high', 'medium')}
                        foreach ($risk in $aggregated) {
                            Out-LogFile ("Found " + $risk.Count + " sign-ins with aggregated risk level: " + $risk.Name) -silentnotice
                        }

                        Out-LogFile ("Review EntraSignInLog_$User.csv/json for complete details") -silentnotice
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
        # Only show completion message if successful
        if ($global:processSuccess) {
            Out-LogFile "Completed exporting Entra sign-in logs" -Information
        }
        Remove-Variable -Name processSuccess -Scope Global -ErrorAction SilentlyContinue
    }
}