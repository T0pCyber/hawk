Function Get-HawkTenantEntraSignInLog {
    <#
    .SYNOPSIS
        Retrieves medium and high risk Microsoft Entra ID sign-in logs using Microsoft Graph.

    .DESCRIPTION
        This function retrieves risky sign-in logs from Microsoft Entra ID (formerly Azure AD) 
        using the Microsoft Graph API. It specifically collects sign-ins that were marked as
        medium or high risk either during sign-in or after aggregated risk analysis.

        The function:
        - Filters for medium and high risk sign-ins at the API level
        - Automatically handles pagination of large result sets
        - Displays progress during data collection
        - Exports data in both CSV and JSON formats
        - Uses the configured Hawk date range
        
    .OUTPUTS
        File: RiskySignInLog.csv/.json
        Path: \Tenant
        Description: Medium and high risk sign-in logs from Microsoft Entra ID 

    .EXAMPLE
        Get-HawkTenantEntraSignInLog

        Retrieves risky sign-in logs from the configured Hawk time window.

    .NOTES
        Requires Microsoft.Graph.Authentication module
        Requires appropriate Microsoft Graph permissions (AuditLog.Read.All)
    #>
    [CmdletBinding()]
    param()

    BEGIN {
        # Check if Hawk object exists and is fully initialized
        if (Test-HawkGlobalObject) {
            Initialize-HawkGlobalObject
        }

        Out-LogFile "Gathering Risky Microsoft Entra ID Sign-in Logs" -Action

        # Verify Graph API connection
        Test-GraphConnection
        Send-AIEvent -Event "CmdRun"

        # Create tenant folder if it doesn't exist
        $TenantPath = Join-Path -Path $Hawk.FilePath -ChildPath "Tenant"
        if (-not (Test-Path -Path $TenantPath)) {
            New-Item -Path $TenantPath -ItemType Directory -Force | Out-Null
        }
    }

    PROCESS {
        try {
            Out-LogFile "Retrieving high and medium risk sign-in logs from Microsoft Graph..." -Action

            # Build filter for medium or high risk levels
            $filter = "(riskLevelDuringSignIn eq 'high' or riskLevelDuringSignIn eq 'medium' or " +
                      "riskLevelAggregated eq 'high' or riskLevelAggregated eq 'medium')"

            # Get filtered sign-in logs with progress tracking
            $processedCount = 0
            $signInLogs = Get-MgAuditLogSignIn -Filter $filter -All -ErrorAction Stop

            foreach ($log in $signInLogs) {
                $processedCount++
                
                # Update progress every 100 items
                if ($processedCount % 100 -eq 0) {
                    Write-Progress -Activity "Retrieving Risky Entra Sign-in Logs" `
                        -Status "Processed $processedCount logs" `
                        -PercentComplete -1
                }
            }

            Write-Progress -Activity "Retrieving Risky Entra Sign-in Logs" -Completed

            if ($signInLogs.Count -gt 0) {
                Out-LogFile "Retrieved $($signInLogs.Count) risky sign-in log entries" -Information
                Out-LogFile "Risk Level Breakdown:" -Information
                
                # Provide risk level breakdown
                $riskBreakdown = $signInLogs | Group-Object -Property RiskLevelDuringSignIn | 
                    Select-Object Name, Count | Sort-Object -Property Name
                foreach ($risk in $riskBreakdown) {
                    Out-LogFile "  Risk During Sign-in - $($risk.Name): $($risk.Count) events" -Information
                }
                
                $aggregatedBreakdown = $signInLogs | Group-Object -Property RiskLevelAggregated | 
                    Select-Object Name, Count | Sort-Object -Property Name
                foreach ($risk in $aggregatedBreakdown) {
                    Out-LogFile "  Aggregated Risk - $($risk.Name): $($risk.Count) events" -Information
                }

                $signInLogs | Out-MultipleFileType -FilePrefix "RiskySignInLog" -csv -json
            }
            else {
                Out-LogFile "No risky sign-in logs found in the specified time period" -Information
            }
        }
        catch {
            Out-LogFile "Error retrieving sign-in logs: $($_.Exception.Message)" -isError
            Write-Error -ErrorRecord $_ -ErrorAction Continue
        }
    }

    END {
        Out-LogFile "Completed exporting risky Entra sign-in logs" -Information
    }
}