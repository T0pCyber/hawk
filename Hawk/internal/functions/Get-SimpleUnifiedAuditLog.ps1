Function Get-SimpleUnifiedAuditLog {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSObject]$Record
    )

    Begin {
        $Results = @()
    }

    Process {
        try {
            # Convert the AuditData JSON string to an object
            $AuditData = $Record | Select-Object -ExpandProperty AuditData | ConvertFrom-Json

            if ($AuditData) {
                $obj = [PSCustomObject]@{
                    Caller         = $AuditData.UserId
                    Cmdlet         = $AuditData.Operation
                    FullCommand    = $AuditData.Operation
                    'RunDate(UTC)' = $AuditData.CreationTime
                    ObjectModified = $AuditData.ObjectId
                }

                # Add parameters to FullCommand
                if ($AuditData.Parameters) {
                    $paramStrings = foreach ($param in $AuditData.Parameters) {
                        $value = switch -Regex ($param.Value) {
                            '^\s+|\s+$' { "'$($param.Value)'" } # Has leading/trailing spaces
                            '\s' { "'$($param.Value)'" }        # Contains spaces
                            '^True$|^False$' { "`$$($param.Value.ToLower())" } # Boolean
                            default { $param.Value }
                        }
                        "-$($param.Name) $value"
                    }
                    $obj.FullCommand = "$($AuditData.Operation) $($paramStrings -join ' ')"
                }

                $Results += $obj
            }
        }
        catch {
            Write-Verbose "Error processing record: $_"
        }
    }

    End {
        $Results
    }
}