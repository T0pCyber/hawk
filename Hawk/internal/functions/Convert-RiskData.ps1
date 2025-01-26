function Convert-HawkRiskData {
    <#
    .SYNOPSIS
        Parses and flattens risk detection additional information data.

    .DESCRIPTION
        Internal helper function that processes additional information from risk detection
        data, converting nested JSON structures into a flat format suitable for 
        Get-SimpleUnifiedAuditLog processing.

        Handles common risk data fields including:
        - riskReasons (array)
        - userAgent
        - alertUrl
        - mitreTechniques

    .PARAMETER RiskData
        Risk detection or user data containing AdditionalInfo property with JSON data.

    .EXAMPLE
        $parsedData = Convert-HawkRiskData -RiskData $riskDetections
        $parsedData | Get-SimpleUnifiedAuditLog

        Parses risk detection data before passing to Get-SimpleUnifiedAuditLog.

    .NOTES
        Internal function for use by Hawk risk analysis functions.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object[]]$RiskData
    )

    begin {
        $processedData = @()
    }

    process {
        foreach ($record in $RiskData) {
            # Create copy of original record excluding AdditionalInfo
            $processedRecord = $record | Select-Object * -ExcludeProperty AdditionalInfo

            if ($record.AdditionalInfo) {
                try {
                    # Parse JSON if string, otherwise use as-is
                    if ($record.AdditionalInfo -is [string]) {
                        $additionalInfo = $record.AdditionalInfo | ConvertFrom-Json
                    }
                    else {
                        $additionalInfo = $record.AdditionalInfo
                    }

                    # Convert each key-value pair to a property
                    foreach ($item in $additionalInfo) {
                        $propertyName = "AdditionalInfo_$($item.Key)"
                        if ($item.Value -is [array]) {
                            # Join array values with pipe delimiter
                            $propertyValue = $item.Value -join '|'
                        }
                        else {
                            $propertyValue = $item.Value
                        }

                        # Add as new property to processed record
                        Add-Member -InputObject $processedRecord -MemberType NoteProperty -Name $propertyName -Value $propertyValue -Force
                    }
                }
                catch {
                    Write-Warning "Error processing AdditionalInfo for record: $_"
                }
            }

            $processedData += $processedRecord
        }
    }

    end {
        return $processedData
    }
}