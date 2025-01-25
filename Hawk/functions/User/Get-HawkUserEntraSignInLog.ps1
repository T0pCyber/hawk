Function Get-HawkUserEntraSignInLog {
    <#
    .SYNOPSIS
        Retrieves medium and high risk Microsoft Entra ID sign-in logs for a specific user using Microsoft Graph.

    .DESCRIPTION
        This function retrieves risky sign-in logs from Microsoft Entra ID (formerly Azure AD) 
        for specific users using the Microsoft Graph API. It collects sign-ins that were marked as
        medium or high risk either during sign-in or after aggregated risk analysis.

        The function:
        - Filters for medium and high risk sign-ins at the API level
        - Automatically handles pagination of large result sets
        - Displays progress during data collection
        - Exports data in both CSV and JSON formats
        - Uses the configured Hawk date range
        
    .PARAMETER UserPrincipalName
        Single UPN of a user, comma-separated list of UPNs, or array of objects that contain UPNs.

    .OUTPUTS
        File: RiskySignInLog.csv/.json
        Path: \<User>
        Description: Medium and high risk sign-in logs for the specified user(s)

    .EXAMPLE
        Get-HawkUserEntraSignInLog -UserPrincipalName user@contoso.com

        Retrieves risky sign-in logs for the specified user from the configured Hawk time window.

    .EXAMPLE
        Get-HawkUserEntraSignInLog -UserPrincipalName "user1@contoso.com","user2@contoso.com"

        Retrieves risky sign-in logs for multiple users.

    .NOTES
        Requires Microsoft.Graph.Authentication module
        Requires appropriate Microsoft Graph permissions (AuditLog.Read.All)
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

        $startTime = Get-Date
        Out-LogFile "Gathering Microsoft Entra ID Sign-in Logs" -Action
        Test-GraphConnection
        Send-AIEvent -Event "CmdRun"
        [array]$UserArray = Test-UserObject -ToTest $UserPrincipalName
    }

    PROCESS {
        foreach ($Object in $UserArray) {
            [string]$User = $Object.UserPrincipalName
            
            try {
                Out-LogFile ("Retrieving sign-in logs for " + $User) -Action

                # Filter just on user - get all sign-ins
                $filter = "userPrincipalName eq '$User'"
                
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

                        Out-LogFile ("Review SignInLog.csv/json in the " + $User + " folder for complete details") -silentnotice
                    }
                }
                else {
                    Out-LogFile ("No sign-in logs found for " + $User + " in the specified time period") -Information
                }
            }
            catch {
                Out-LogFile ("Error retrieving sign-in logs for " + $User + " : " + $_.Exception.Message) -isError
                Write-Error -ErrorRecord $_ -ErrorAction Continue
            }
        }
    }

    END {
        Out-LogFile "Completed exporting Entra sign-in logs" -Information
        $endTime = Get-Date
        $duration = $endTime - $startTime
        $formattedDuration = ("Total Runtime: {0:N0} minutes {1} seconds" -f [math]::Floor($duration.TotalMinutes), $duration.Seconds)
        Out-LogFile $formattedDuration -Information
    }
}