Function Get-SimpleUnifiedAuditLog {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSObject]$UALRecord
    )

    Begin {
        Write-Verbose "Starting Get-SimpleUnifiedAuditLog processing"
        $Results = @()
    }

    Process {
        foreach ($record in $UALRecord) {
            try {
                Write-Verbose "Processing record with ID: $($record.Identity)"

                # The AuditData is a JSON string, so convert it
                if ($record.AuditData) {
                    $AuditRecord = $record.AuditData | ConvertFrom-Json

                    # Create result object with data from audit record
                    $obj = [PSCustomObject]@{
                        Caller         = if ($AuditRecord.UserId) { $AuditRecord.UserId } else { "***" }
                        Cmdlet         = $AuditRecord.Operation
                        FullCommand    = $AuditRecord.Operation
                        'RunDate(UTC)' = $AuditRecord.CreationTime
                        ObjectModified = $AuditRecord.ObjectId
                    }

                    # Add parameters to FullCommand if they exist
                    if ($AuditRecord.Parameters) {
                        $paramString = foreach ($param in $AuditRecord.Parameters) {
                            # Handle different parameter value types appropriately
                            $value = if ($param.Value -match '\s') {
                                # If value contains spaces, quote it
                                "'$($param.Value)'"
                            } elseif ($param.Value -match '^(True|False)$') {
                                # If boolean, format with $
                                "`$$($param.Value.ToLower())"
                            } else {
                                $param.Value
                            }
                            "-$($param.Name) $value"
                        }
                        $obj.FullCommand = "$($obj.Cmdlet) $($paramString -join ' ')"
                    }

                    $Results += $obj
                    Write-Verbose "Successfully processed record"
                }
                else {
                    Write-Verbose "No AuditData found for record"
                    $Results += [PSCustomObject]@{
                        Caller         = "***"
                        Cmdlet         = "Unknown"
                        FullCommand    = "No audit data available"
                        'RunDate(UTC)' = $null
                        ObjectModified = $null
                    }
                }
            }
            catch {
                Write-Verbose "Error processing record: $_"
                $Results += [PSCustomObject]@{
                    Caller         = "***"
                    Cmdlet         = "Error"
                    FullCommand    = "Error processing audit record: $_"
                    'RunDate(UTC)' = $null
                    ObjectModified = $null
                }
            }
        }
    }

    End {
        Write-Verbose "Completed processing. Returning $($Results.Count) records"
        return $Results
    }
}