Function Get-HawkTenantRiskyUsers {
    <#
    .SYNOPSIS
        Retrieves and analyzes users flagged as risky in Microsoft Entra ID.

    .DESCRIPTION
        Uses Microsoft Graph API to retrieve a list of users that have been flagged as risky
        in Microsoft Entra ID. The function analyzes user risk levels and states to identify
        potentially compromised accounts requiring immediate investigation.

        The function requires the following Microsoft Graph permissions:
        - IdentityRiskyUser.Read.All

    .EXAMPLE
        Get-HawkTenantRiskyUsers

        Retrieves all risky users from Entra ID, including their risk levels and risk states.
        High risk users are automatically flagged for investigation.

    .OUTPUTS
        File: RiskyUsers.csv/.json
        Path: \Tenant
        Description: All users currently flagged as risky in Entra ID

        File: _Investigate_HighRiskUsers.csv/.json
        Path: \Tenant
        Description: Users with high risk levels requiring immediate investigation

    .NOTES
        This function requires appropriate Graph API permissions to access risky user data.
        Ensure your authenticated account has IdentityRiskyUser.Read.All permission.
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

            Out-LogFile ("Total risky users found: " + $riskyUsers.Count) -Information
            
            # Define risk level order for consistent sorting
            $riskOrder = @{
                'high'   = 1
                'medium' = 2
                'low'    = 3
                'none'   = 4
            }
            
            # Log summary of users by risk level
            $riskLevels = $riskyUsers | Group-Object -Property RiskLevel | 
                Sort-Object -Property { $riskOrder[$_.Name] }
            
            foreach ($level in $riskLevels) {
                $capitalizedName = $level.Name.Substring(0, 1).ToUpper() + $level.Name.Substring(1).ToLower()
                Out-LogFile ("- $($level.Count) users at Risk Level '${capitalizedName}'") -Information
            }
            
            # Export all risky users
            $riskyUsers | Out-MultipleFileType -FilePrefix "RiskyUsers" -csv -json
            
            # Group users by risk level and compromise state for investigation
            $riskyUserGroups = @{
                Compromised = $riskyUsers | Where-Object { 
                    $_.RiskState -eq 'confirmedCompromised' 
                }
                High = $riskyUsers | Where-Object { 
                    $_.RiskLevel -eq 'high' 
                }
                Medium = $riskyUsers | Where-Object { 
                    $_.RiskLevel -eq 'medium'
                }
                Low = $riskyUsers | Where-Object { 
                    $_.RiskLevel -eq 'low'
                }
            }

            # Process compromised users
            if ($riskyUserGroups.Compromised) {
                Out-LogFile "Found $($riskyUserGroups.Compromised.Count) confirmed compromised accounts" -Notice
                Out-LogFile "Details in _Investigate_Compromised_Users files" -Notice
                $riskyUserGroups.Compromised | Out-MultipleFileType -FilePrefix "_Investigate_Compromised_Users" -json -Notice
            }

            # Combine High, Medium, and Low risk users into a single collection
            $nonCompromisedRiskUsers = @()
            if ($riskyUserGroups.High) {
                Out-LogFile ("Found " + $riskyUserGroups.High.Count + " High Risk users requiring immediate investigation") -Notice
                foreach ($user in $riskyUserGroups.High) {
                    Out-LogFile ("High Risk user detected: $($user.UserPrincipalName)") -Notice
                    Out-LogFile ("Risk Level: $($user.RiskLevel), Risk State: $($user.RiskState)") -Notice
                }
                $nonCompromisedRiskUsers += $riskyUserGroups.High
            }

            if ($riskyUserGroups.Medium) {
                Out-LogFile ("Found " + $riskyUserGroups.Medium.Count + " Medium Risk users requiring investigation") -Notice
                foreach ($user in $riskyUserGroups.Medium) {
                    Out-LogFile ("Medium Risk user detected: $($user.UserPrincipalName)") -Notice
                    Out-LogFile ("Risk Level: $($user.RiskLevel), Risk State: $($user.RiskState)") -Notice
                }
                $nonCompromisedRiskUsers += $riskyUserGroups.Medium
            }

            if ($riskyUserGroups.Low) {
                Out-LogFile ("Found " + $riskyUserGroups.Low.Count + " Low Risk users for review") -Notice
                foreach ($user in $riskyUserGroups.Low) {
                    Out-LogFile ("Low Risk user detected: $($user.UserPrincipalName)") -Notice
                    Out-LogFile ("Risk Level: $($user.RiskLevel), Risk State: $($user.RiskState)") -Notice
                }
                $nonCompromisedRiskUsers += $riskyUserGroups.Low
            }

            # Combine High, Medium, and Low risk users summary
            if ($nonCompromisedRiskUsers.Count -gt 0) {
                $highRisk = ($riskyUserGroups.High).Count
                $mediumRisk = ($riskyUserGroups.Medium).Count
                $lowRisk = ($riskyUserGroups.Low).Count
                
                Out-LogFile "Found risky users: $highRisk High, $mediumRisk Medium, $lowRisk Low" -Notice
                Out-LogFile "Details in _Investigate_Risky_Users.csv/json" -Notice
                $nonCompromisedRiskUsers | Out-MultipleFileType -FilePrefix "_Investigate_Risky_Users" -csv -json -Notice
            }
        }
        catch {
            Out-LogFile "Error retrieving risky users: $($_.Exception.Message)" -isError
            Write-Error -ErrorRecord $_ -ErrorAction Continue
        }
    }

    end {
        Out-LogFile "Completed gathering Risky User Log" -Information
    }
}
