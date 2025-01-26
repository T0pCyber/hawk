Function Get-HawkTenantRiskyServicePrincipals {
    <#
    .SYNOPSIS
        Retrieves risky service principals from Microsoft Entra ID.

    .DESCRIPTION
        Uses Microsoft Graph API to retrieve service principals that have been
        identified as risky in Microsoft Entra ID. The function analyzes sign-in patterns,
        suspicious activities, and risk levels associated with service principals.

        IMPORTANT: This functionality requires a Microsoft Entra Workload ID Premium license.
        If you do not have this license, the function will return no results.

        The function:
        - Retrieves all risky service principal sign-ins
        - Groups findings by risk level
        - Flags high-risk service principals for investigation
        - Exports detailed findings in both CSV and JSON formats

        Risk levels are categorized as:
        - High: Requires immediate investigation
        - Medium: Should be reviewed but less urgent
        - Low: Minimal risk but worth monitoring

    .OUTPUTS
        File: RiskyServicePrincipals.csv/.json
        Path: \Tenant
        Description: All risky service principals with details about their risk state

        File: _Investigate_HighRiskServicePrincipals.csv/.json
        Path: \Tenant
        Description: Service principals with high risk levels requiring immediate review

    .EXAMPLE
        Get-HawkTenantRiskyServicePrincipals

        Retrieves all service principals flagged as risky in the tenant, categorizing
        them by risk level and highlighting those requiring immediate attention.

    .NOTES
        Required License: Microsoft Entra Workload ID Premium
        
        This function requires the following Microsoft Graph permissions:
        - ServicePrincipalRiskDetection.Read.All
        - AuditLog.Read.All
        - Directory.Read.All

        The function follows the same risk categorization and output patterns as 
        Get-HawkTenantRiskyUsers and Get-HawkTenantRiskDetections.

    .LINK
        https://learn.microsoft.com/en-us/graph/api/serviceprincipalriskdetection-get
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

        # Check for required license
        $licenseCheck = Test-EntraWorkloadIDPremium
        if (-not $licenseCheck.HasLicense) {
            Out-LogFile "Entra Workload ID Premium license not found" -isWarning
            Out-LogFile "No Entra Workload ID Premium capable licenses found." -Information
            Out-LogFile "Required licenses: AAD_PREMIUM_P2, ENTERPRISEPREMIUM, SPE_E5, IDENTITY_THREAT_PROTECTION" -Information
            Out-LogFile "The service principal risk detection requires one of these licenses to function" -Information
            return
        }

        Out-LogFile "Retrieving risky service principals from Microsoft Entra ID" -Action

        # Create tenant folder if it doesn't exist
        $TenantPath = Join-Path -Path $Hawk.FilePath -ChildPath "Tenant"
        if (-not (Test-Path -Path $TenantPath)) {
            New-Item -Path $TenantPath -ItemType Directory -Force | Out-Null
        }
    }

    process {
        try {
            # Get risky service principals
            Out-LogFile "Retrieving risky service principal data" -Action
            $riskyServicePrincipals = Get-MgServicePrincipalRiskDetection -All -ErrorAction Stop

            if ($null -eq $riskyServicePrincipals -or $riskyServicePrincipals.Count -eq 0) {
                Out-LogFile "No risky service principals found" -Information
                Out-LogFile "Note: This API requires Microsoft Entra Workload ID Premium license" -Information
                Out-LogFile "If you have the license and still see no data, verify your Graph API permissions" -Information
                return
            }

            Out-LogFile ("Total risky service principals found: " + $riskyServicePrincipals.Count) -Information

            # Export all risky service principals
            $riskyServicePrincipals | Out-MultipleFileType -FilePrefix "RiskyServicePrincipals" -csv -json

            # Define risk level order for sorting
            $riskOrder = @{
                'high' = 1
                'medium' = 2
                'low' = 3
                'none' = 4
            }

            # Log summary of service principals by risk level
            $riskLevels = $riskyServicePrincipals | Group-Object -Property RiskLevel | 
                Sort-Object -Property { $riskOrder[$_.Name] }

            foreach ($level in $riskLevels) {
                $capitalizedName = $level.Name.Substring(0, 1).ToUpper() + $level.Name.Substring(1).ToLower()
                Out-LogFile ("- $($level.Count) Service Principals at Risk Level '${capitalizedName}'") -Information
            }

            # Identify high risk service principals
            $highRiskSPs = $riskyServicePrincipals | Where-Object { 
                $_.RiskLevel -eq 'high' -or
                $_.RiskState -eq 'atRisk' -or
                $_.RiskState -eq 'confirmedCompromised'
            }

            if ($highRiskSPs) {
                Out-LogFile ("Found " + $highRiskSPs.Count + " high risk service principals requiring investigation") -Notice

                # Group high risk SPs by app for clearer reporting
                $groupedSPs = $highRiskSPs | Group-Object -Property DisplayName
                foreach ($group in $groupedSPs) {
                    Out-LogFile ("High risk service principal: $($group.Name)") -Notice
                    foreach ($sp in $group.Group) {
                        $riskDetails = "Risk Level = $($sp.RiskLevel), Risk State = $($sp.RiskState)"
                        if ($sp.RiskLastUpdatedDateTime) {
                            $riskDetails += ", Last Updated = $($sp.RiskLastUpdatedDateTime)"
                        }
                        Out-LogFile ("- $riskDetails") -Notice
                    }
                }

                # Export high risk service principals for investigation
                $highRiskSPs | Out-MultipleFileType -FilePrefix "_Investigate_HighRiskServicePrincipals" -csv -json -Notice
            }
        }
        catch {
            if ($_.Exception.Response.StatusCode -eq 403) {
                Out-LogFile "Access Denied: This API requires Microsoft Entra Workload ID Premium license" -isError
                Out-LogFile "Please verify your license and Graph API permissions" -Information
            }
            else {
                Out-LogFile "Error retrieving risky service principals: $($_.Exception.Message)" -isError
            }
            Write-Error -ErrorRecord $_ -ErrorAction Continue
        }
    }

    end {
        Out-LogFile "Completed gathering risky service principal data" -Information
    }
}