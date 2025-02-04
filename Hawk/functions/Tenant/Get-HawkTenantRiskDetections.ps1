Function Get-HawkTenantRiskDetections {
    <#
    .SYNOPSIS
        Retrieves risk detection events from Microsoft Entra ID.

    .DESCRIPTION
        Uses Microsoft Graph API to retrieve risk detection events from Microsoft Entra ID.
        The function gathers details about various types of risk detections, helping security
        teams identify and investigate potential security incidents.

        The function requires the following Microsoft Graph permissions:
        - IdentityRiskEvent.Read.All

    .EXAMPLE
        Get-HawkTenantRiskyDetections

        Retrieves all risk detections from Entra ID, including detection types and details.

    .OUTPUTS
        File: Risk_Detections.csv/.json
        Path: \Tenant
        Description: Risky detections for users in Entra ID

    .NOTES
        This function requires appropriate Graph API permissions to access risk detection data.
        Ensure your authenticated account has IdentityRiskEvent.Read.All permission.
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

        Out-LogFile "Retrieving risk detections from Microsoft Entra ID" -Action

        # Create tenant folder if it doesn't exist
        $TenantPath = Join-Path -Path $Hawk.FilePath -ChildPath "Tenant"
        if (-not (Test-Path -Path $TenantPath)) {
            New-Item -Path $TenantPath -ItemType Directory -Force | Out-Null
        }
    }

    process {
        try {
            # Get risk detections
            Out-LogFile "Retrieving risk detections" -Action
            $riskDetections = Get-MgRiskDetection -All

            if ($null -eq $riskDetections -or $riskDetections.Count -eq 0) {
                Out-LogFile "No risk detections found" -Information
                return
            }

            # Process and flatten risk detection data
            $processedDetections = Convert-HawkRiskData -RiskData $riskDetections 

            Out-LogFile ("Total risk detections found: " + $processedDetections.Count) -Information

            # Export flattened data to CSV for analysis
            $processedDetections | Out-MultipleFileType -FilePrefix "Risk_Detections" -csv

            # Export original data to JSON to preserve structure
            $riskDetections | Out-MultipleFileType -FilePrefix "Risk_Detections" -json
            
            # Define risk level order
            $riskOrder = @{
                'high'   = 1
                'medium' = 2
                'low'    = 3
                'none'   = 4
            }
            
            # Log summary of detections by risk level
            $riskLevels = $processedDetections | Group-Object -Property RiskLevel | 
            Sort-Object -Property { $riskOrder[$_.Name] }
            
            foreach ($level in $riskLevels) {
                $capitalizedName = $level.Name.Substring(0, 1).ToUpper() + $level.Name.Substring(1).ToLower()
                Out-LogFile ("- $($level.Count) Risk Detections at Risk Level '${capitalizedName}'") -Information
            }

            # Identify high risk detections
            $highRiskDetections = $processedDetections | Where-Object { 
                $_.RiskLevel -eq 'high' -or
                $_.RiskState -eq 'atRisk' -or
                $_.RiskState -eq 'confirmedCompromised'
            }

            if ($highRiskDetections) {
                Out-LogFile ("Found " + $highRiskDetections.Count + " high risk detections requiring investigation") -Notice
                
                # Group high risk detections by user for clearer reporting
                $groupedDetections = $highRiskDetections | Group-Object -Property UserPrincipalName
                foreach ($group in $groupedDetections) {
                    Out-LogFile ("High risk detections for user: $($group.Name)") -Notice
                    foreach ($detection in $group.Group) {
                        Out-LogFile ("- $($detection.RiskEventType) at $($detection.DetectedDateTime): Risk Level = $($detection.RiskLevel), Risk State = $($detection.RiskState)") -Notice
                    }
                }

                # Export flattened high risk detections for investigation
                $highRiskDetections | Out-MultipleFileType -FilePrefix "_Investigate_High_Risk_Detections" -csv -json -Notice
            }
        }
        catch {
            Out-LogFile "Error retrieving risk detections: $($_.Exception.Message)" -isError
            Write-Error -ErrorRecord $_ -ErrorAction Continue
        }
    }

    end {
        Out-LogFile "Completed gathering risk detection data" -Information
    }
}