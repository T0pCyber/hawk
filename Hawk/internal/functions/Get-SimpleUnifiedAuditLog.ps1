Function Get-SimpleUnifiedAuditLog {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        $UALRecord
    )

    Begin {
        $Results = @()
    }

    Process {
        try {
            # The AuditData is already JSON in the UALRecord object
            $AuditRecord = $UALRecord.AuditData | ConvertFrom-Json

            # Check if we got valid data
            if ($AuditRecord) {
                # Extract the user who ran the command
                $User = if ([string]::IsNullOrEmpty($AuditRecord.UserId)) {
                    "***"
                } else {
                    $AuditRecord.UserId
                }

                # Create result object
                $obj = [PSCustomObject]@{
                    Caller         = $User
                    Cmdlet         = $AuditRecord.Operation
                    FullCommand    = "$($AuditRecord.Operation) $(($AuditRecord.Parameters | ForEach-Object { "-$($_.Name) '$($_.Value)'" }) -join ' ')"
                    'RunDate(UTC)' = $AuditRecord.CreationTime
                    ObjectModified = $AuditRecord.ObjectId
                }

                $Results += $obj
            }
        }
        catch {
            Write-Verbose "Error processing record: $_"
            # Add empty record to maintain count
            $Results += [PSCustomObject]@{
                Caller         = "***"
                Cmdlet         = $null
                FullCommand    = $null
                'RunDate(UTC)' = $null
                ObjectModified = $null
            }
        }
    }

    End {
        $Results
    }
}