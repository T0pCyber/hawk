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

            # Split detections into confirmed compromised and other (high/medium/low) groups
            $confirmedCompromisedDetections = $processedDetections | Where-Object { $_.RiskState -eq 'confirmedCompromised' }
            $otherDetections = $processedDetections | Where-Object { 
                $_.RiskState -ne 'confirmedCompromised' -and 
                ($_.RiskLevel -eq 'high' -or $_.RiskLevel -eq 'medium' -or $_.RiskLevel -eq 'low')
            }

            # Process confirmed compromised risk detections
            if ($confirmedCompromisedDetections) {
                Out-LogFile "Found $($confirmedCompromisedDetections.Count) confirmed compromised risk detections" -Notice
                Out-LogFile "Details in _Investigate_Confirmed_Compromised_Risk_Detection files" -Notice
                $confirmedCompromisedDetections | Out-MultipleFileType -FilePrefix "_Investigate_Confirmed_Compromised_Risk_Detection" -csv -json -Notice
            }

            # Process other risk detections (combined high/medium/low)
            if ($otherDetections) {
                $highRisk = ($otherDetections | Where-Object { $_.RiskLevel -eq 'high' }).Count
                $mediumRisk = ($otherDetections | Where-Object { $_.RiskLevel -eq 'medium' }).Count
                $lowRisk = ($otherDetections | Where-Object { $_.RiskLevel -eq 'low' }).Count
                
                Out-LogFile "Found risk detections: $highRisk High, $mediumRisk Medium, $lowRisk Low" -Notice
                Out-LogFile "Details in _Investigate_Risk_Detection files" -Notice
                $otherDetections | Out-MultipleFileType -FilePrefix "_Investigate_Risk_Detection" -csv -json -Notice
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
