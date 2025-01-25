Function Get-HawkUserEntraIDSignInLog {
    <#
    .SYNOPSIS
        Retrieves medium and high-risk Microsoft Entra ID sign-in logs for specific users using Microsoft Graph.

    .DESCRIPTION
        This function collects sign-in logs from Microsoft Entra ID (formerly Azure AD) for specified users via the Microsoft Graph API. 
        It identifies risky sign-ins that were marked as medium or high risk during sign-in or after aggregated risk analysis.

        Key Features:
        - Automatically handles pagination for large data sets.
        - Exports data in both CSV and JSON formats for analysis.
        - Filters and highlights medium and high-risk sign-ins.
        - Groups sign-in data by risk levels for easier review.
        - Utilizes the configured Hawk date range for investigation.

        Improvements in this version:
        - Added standardized JSON output for sign-in logs.
        - Enhanced grouping and reporting of risk levels.
        - Logs grouped data for both "RiskLevelDuringSignIn" and "RiskLevelAggregated".

    .PARAMETER UserPrincipalName
        Accepts one or more User Principal Names (UPNs) as input.
        Input can be:
        - A single UPN (e.g., user@contoso.com)
        - A comma-separated list of UPNs
        - An array of objects containing UPNs

    .OUTPUTS
        Files:
            - EntraSignInLog_<User>.csv
            - EntraSignInLog_<User>.json
        Path:
            - Saved under the corresponding user's folder.
        Description:
            - Sign-in logs highlighting medium and high-risk entries for the specified users.

    .EXAMPLE
        Get-HawkUserEntraIDSignInLog -UserPrincipalName user@contoso.com
        Retrieves sign-in logs for the specified user and flags medium and high-risk sign-ins.

    .EXAMPLE
        Get-HawkUserEntraIDSignInLog -UserPrincipalName "user1@contoso.com","user2@contoso.com"
        Retrieves sign-in logs for multiple users and exports results for each user.

    .NOTES
        Dependencies:
            - Requires the Microsoft.Graph.Authentication module.
            - Requires Microsoft Graph permissions: AuditLog.Read.All.

        Known Limitations:
            - The function relies on the configured Hawk date range and cannot retrieve logs beyond Microsoft Graph's 30-day limit.
            - Ensure appropriate permissions are granted to the connected Microsoft Graph app.

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
    }
}