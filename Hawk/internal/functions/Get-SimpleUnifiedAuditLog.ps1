function Get-SimpleUnifiedAuditLog {
    <#
    .SYNOPSIS
        Flattens nested Microsoft 365 Unified Audit Log records into a simplified format.

    .DESCRIPTION
        This function processes Microsoft 365 Unified Audit Log records by converting nested JSON data
        (stored in the AuditData property) into a flat structure suitable for analysis and export.
        It handles complex nested objects, arrays, and special cases like parameter collections.

        The function:
        - Preserves base record properties
        - Flattens nested JSON structures
        - Provides special handling for Parameters collections
        - Creates human-readable command reconstructions
        - Supports type preservation for data analysis

    .PARAMETER Record
        A PowerShell object representing a unified audit log record. Typically, this is the output
        from Search-UnifiedAuditLog and should contain both base properties and an AuditData
        property containing a JSON string of additional audit information.

    .PARAMETER PreserveTypes
        When specified, maintains the original data types of values instead of converting them
        to strings. This is useful when the output will be used for further PowerShell processing
        rather than export to CSV/JSON.

    .EXAMPLE
        $auditLogs = Search-UnifiedAuditLog -StartDate $startDate -EndDate $endDate -RecordType ExchangeAdmin
        $auditLogs | Get-SimpleUnifiedAuditLog | Export-Csv -Path "AuditLogs.csv" -NoTypeInformation

        Processes Exchange admin audit logs and exports them to CSV with all nested properties flattened.

    .EXAMPLE
        $userChanges = Search-UnifiedAuditLog -UserIds user@domain.com -Operations "Add-*"
        $userChanges | Get-SimpleUnifiedAuditLog -PreserveTypes |
            Where-Object { $_.ResultStatus -eq $true } |
            Select-Object CreationTime, Operation, FullCommand

        Gets all "Add" operations for a specific user, preserves data types, filters for successful operations,
        and selects specific columns.

    .OUTPUTS
        Collection of PSCustomObjects with flattened properties from both the base record and AuditData.
        Properties include:
        - All base record properties (RecordType, CreationDate, etc.)
        - Flattened nested objects with property names using dot notation
        - Individual parameters as Param_* properties
        - ParameterString containing all parameters in a readable format
        - FullCommand showing reconstructed PowerShell command (when applicable)

    .NOTES
        Author: Jonathan Butler
        Version: 2.0
        Development Date: December 2024

        The function is designed to handle any RecordType from the Unified Audit Log and will
        automatically adapt to changes in the audit log schema. Special handling is implemented
        for common patterns like Parameters collections while maintaining flexibility for
        other nested structures.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSObject]$Record,

        [Parameter(Mandatory = $false)]
        [switch]$PreserveTypes
    )

    begin {
        # Collection to store processed results
        $Results = @()

        function ConvertTo-FlatObject {
            <#
            .SYNOPSIS
                Recursively flattens nested objects into a single-level hashtable.

            .DESCRIPTION
                Internal helper function that converts complex nested objects into a flat structure
                using dot notation for property names. Handles special cases like Parameters arrays
                and preserves type information when requested.
            #>
            param (
                [Parameter(Mandatory = $true)]
                [PSObject]$InputObject,

                [Parameter(Mandatory = $false)]
                [string]$Prefix = "",

                [Parameter(Mandatory = $false)]
                [switch]$PreserveTypes
            )

            # Initialize hashtable for flattened properties
            $flatProperties = @{}

            # Process each property of the input object
            foreach ($prop in $InputObject.PSObject.Properties) {
                # Build the property key name, incorporating prefix if provided
                $key = if ($Prefix) { "${Prefix}_$($prop.Name)" } else { $prop.Name }

                # Special handling for Parameters array - common in UAL records
                if ($prop.Name -eq 'Parameters' -and $prop.Value -is [Array]) {
                    # Create human-readable parameter string
                    $paramStrings = foreach ($param in $prop.Value) {
                        "$($param.Name)=$($param.Value)"
                    }
                    $flatProperties['ParameterString'] = $paramStrings -join ' | '

                    # Create individual parameter properties
                    foreach ($param in $prop.Value) {
                        $paramKey = "Param_$($param.Name)"
                        $flatProperties[$paramKey] = $param.Value
                    }

                    # Reconstruct full command if Operation property exists
                    if ($InputObject.Operation) {
                        $paramStrings = foreach ($param in $prop.Value) {
                            # Format parameter values based on content
                            $value = switch -Regex ($param.Value) {
                                '\s' { "'$($param.Value)'" } # Quote values containing spaces
                                '^True$|^False$' { "`$$($param.Value.ToLower())" } # Format booleans
                                ';' { "'$($param.Value)'" } # Quote values containing semicolons
                                default { $param.Value }
                            }
                            "-$($param.Name) $value"
                        }
                        $flatProperties['FullCommand'] = "$($InputObject.Operation) $($paramStrings -join ' ')"
                    }
                    continue
                }

                # Handle different value types
                switch ($prop.Value) {
                    # Recursively process nested hashtables
                    { $_ -is [System.Collections.IDictionary] } {
                        $nestedObject = ConvertTo-FlatObject -InputObject $_ -Prefix $key -PreserveTypes:$PreserveTypes
                        $flatProperties += $nestedObject
                    }
                    # Process arrays (excluding Parameters which was handled above)
                    { $_ -is [System.Collections.IList] -and $prop.Name -ne 'Parameters' } {
                        if ($_.Count -gt 0) {
                            if ($_[0] -is [PSObject]) {
                                # Handle array of objects
                                for ($i = 0; $i -lt $_.Count; $i++) {
                                    $nestedObject = ConvertTo-FlatObject -InputObject $_[$i] -Prefix "${key}_${i}" -PreserveTypes:$PreserveTypes
                                    $flatProperties += $nestedObject
                                }
                            }
                            else {
                                # Handle array of simple values
                                $flatProperties[$key] = $_ -join "|"
                            }
                        }
                        else {
                            # Handle empty arrays
                            $flatProperties[$key] = [string]::Empty
                        }
                    }
                    # Recursively process nested objects
                    { $_ -is [PSObject] } {
                        $nestedObject = ConvertTo-FlatObject -InputObject $_ -Prefix $key -PreserveTypes:$PreserveTypes
                        $flatProperties += $nestedObject
                    }
                    # Handle simple values
                    default {
                        if ($PreserveTypes) {
                            # Keep original type if PreserveTypes is specified
                            $flatProperties[$key] = $_
                        }
                        else {
                            # Convert values to appropriate types
                            $flatProperties[$key] = switch ($_) {
                                { $_ -is [datetime] } { $_ }
                                { $_ -is [bool] } { $_ }
                                { $_ -is [int] } { $_ }
                                { $_ -is [long] } { $_ }
                                { $_ -is [decimal] } { $_ }
                                { $_ -is [double] } { $_ }
                                default { [string]$_ }
                            }
                        }
                    }
                }
            }

            return $flatProperties
        }
    }

    process {
        try {
            # Extract base properties excluding AuditData
            $baseProperties = $Record | Select-Object * -ExcludeProperty AuditData

            # Process AuditData if present
            $auditData = $Record.AuditData | ConvertFrom-Json
            if ($auditData) {
                # Flatten the audit data
                $flatAuditData = ConvertTo-FlatObject -InputObject $auditData -PreserveTypes:$PreserveTypes

                # Combine base properties with flattened audit data
                $combinedProperties = @{}
                $baseProperties.PSObject.Properties | ForEach-Object { $combinedProperties[$_.Name] = $_.Value }
                $flatAuditData.GetEnumerator() | ForEach-Object { $combinedProperties[$_.Key] = $_.Value }

                # Create and store the result
                $Results += [PSCustomObject]$combinedProperties
            }
        }
        catch {
            # Handle and log any processing errors
            Write-Warning "Error processing record: $_"
            $errorProperties = @{
                RecordType = $Record.RecordType
                CreationDate = Get-Date
                Error = $_.Exception.Message
                Record = $Record
            }
            $Results += [PSCustomObject]$errorProperties
        }
    }

    end {
        # Return all processed results
        $Results
    }
}