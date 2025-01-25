Function Get-HawkTenantRiskyUsersAndDetections {
    <#
    .SYNOPSIS
        Retrieves information about users flagged as risky in Microsoft Entra ID.

    .DESCRIPTION
        Uses Microsoft Graph API to retrieve a list of users that have been flagged as risky
        in Microsoft Entra ID. The function gathers details about risk detections, risk levels,
        and risk states, helping security teams identify potentially compromised accounts.

        The function requires the following Microsoft Graph permissions:
        - IdentityRiskyUser.Read.All
        - IdentityRiskEvent.Read.All

    .EXAMPLE
        Get-HawkTenantRiskyUsersAndDetections

        Retrieves all risky users from Entra ID, including their risk levels, risk states,
        and associated risk detections.

    .OUTPUTS
        File: RiskyUsers.csv/.json
        Path: \Tenant
        Description: All users currently flagged as risky in Entra ID

        File: RiskDetections.csv/.json
        Path: \Tenant
        Description: Risk detections for users in Entra ID

        File: _Investigate_HighRiskUsers.csv/.json
        Path: \Tenant
        Description: Users with high risk levels requiring immediate investigation

    .NOTES
        This function requires appropriate Graph API permissions to access risky user data.
        Ensure your authenticated account has the required permissions:
        - IdentityRiskyUser.Read.All
        - IdentityRiskEvent.Read.All   
    #>
    [CmdletBinding()]
    param()

    begin {
        # Check if Hawk object exists and is fully initialized
        if (Test-HawkGlobalObject) {
            Initialize-HawkGlobalObject
        }

        # Test Graph connection and proper permissions
        Test-GraphConnection
        Send-AIEvent -Event "CmdRun"

        Out-LogFile "Retrieving risky users from Microsoft Entra ID" -Action

        # Create tenant folder if it doesn't exist
        $TenantPath = Join-Path -Path $Hawk.FilePath -ChildPath "Tenant"
        if (-not (Test-Path -Path $TenantPath)) {
            New-Item -Path $TenantPath -ItemType Directory -Force | Out-Null
        }
    }

    process {
        try {
            # Get current risky users
            Out-LogFile "Retrieving current risky users" -Action
            $riskyUsers = Get-MgRiskyUser -All

            if ($null -eq $riskyUsers -or $riskyUsers.Count -eq 0) {
                Out-LogFile "No risky users found" -Information
                return
            }

            Out-LogFile ("Found " + $riskyUsers.Count + " risky users") -Information
            
            # Export all risky users
            $riskyUsers | Out-MultipleFileType -FilePrefix "RiskyUsers" -csv -json

            # Get risk detections
            Out-LogFile "Retrieving risk detections" -Action
            $riskDetections = Get-MgRiskDetection -All

            if ($riskDetections) {
                Out-LogFile ("Found " + $riskDetections.Count + " risk detections") -Information
                $riskDetections | Out-MultipleFileType -FilePrefix "RiskDetections" -csv -json

                # Log summary of detection types
                $detectionTypes = $riskDetections | Group-Object -Property RiskEventType | Sort-Object -Property Count -Descending
                Out-LogFile "Risk detection types found:" -Information
                foreach ($type in $detectionTypes) {
                    Out-LogFile ("- $($type.Name): $($type.Count) detections") -Information
                }
            }

            # Flag high risk users for investigation
            $highRiskUsers = $riskyUsers | Where-Object { 
                $_.RiskLevel -eq 'high' -or
                $_.RiskState -eq 'atRisk' -or
                $_.RiskState -eq 'confirmedCompromised'
            }

            if ($highRiskUsers) {
                Out-LogFile ("Found " + $highRiskUsers.Count + " high risk users requiring investigation") -Notice
                foreach ($user in $highRiskUsers) {
                    Out-LogFile ("High risk user detected: $($user.UserPrincipalName)") -Notice
                    Out-LogFile ("Risk Level: $($user.RiskLevel), Risk State: $($user.RiskState)") -Notice

                    # Get risk detections specific to this high risk user
                    $userDetections = $riskDetections | Where-Object { $_.UserPrincipalName -eq $user.UserPrincipalName }
                    if ($userDetections) {
                        Out-LogFile ("Risk detections found: $($userDetections.Count)") -Notice
                        foreach ($detection in $userDetections) {
                            Out-LogFile ("- $($detection.RiskEventType) detected at $($detection.DetectedDateTime)") -Notice
                        }
                    }
                }
                $highRiskUsers | Out-MultipleFileType -FilePrefix "_Investigate_HighRiskUsers" -csv -json -Notice
            }
        }
        catch {
            Out-LogFile "Error retrieving risky users: $($_.Exception.Message)" -isError
            Write-Error -ErrorRecord $_ -ErrorAction Continue
        }
    }

    end {
        Out-LogFile "Completed gathering risky user data" -Information
    }
}