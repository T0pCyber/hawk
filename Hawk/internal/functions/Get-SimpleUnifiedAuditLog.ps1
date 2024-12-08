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
            $AuditData = $Record.AuditData | ConvertFrom-Json

            if ($AuditData) {
                # Create base object with common fields
                $obj = [PSCustomObject]@{
                    # Standard fields from old AdminAuditLog
                    Caller = $AuditData.UserId
                    Cmdlet = $AuditData.Operation
                    FullCommand = $AuditData.Operation # Will be populated with parameters below
                    'RunDate(UTC)' = $AuditData.CreationTime
                    ObjectModified = $AuditData.ObjectId

                    # Additional UAL fields that are valuable for investigations
                    ResultStatus = $AuditData.ResultStatus
                    WorkLoad = $AuditData.Workload
                    ClientIP = $AuditData.ClientIP
                    AppId = $AuditData.AppId
                    AppPoolName = $AuditData.AppPoolName
                    ExternalAccess = $AuditData.ExternalAccess
                    OrganizationName = $AuditData.OrganizationName
                    OriginatingServer = $AuditData.OriginatingServer
                    RequestId = $AuditData.RequestId
                    SessionId = $AuditData.SessionId
                }

                # Build FullCommand including parameters
                if ($AuditData.Parameters) {
                    $paramStrings = foreach ($param in $AuditData.Parameters) {
                        $value = switch -Regex ($param.Value) {
                            # Has spaces - quote it
                            '\s' { "'$($param.Value)'" }
                            # Boolean - add $ prefix
                            '^True$|^False$' { "`$$($param.Value.ToLower())" }
                            # Contains semicolons - handle as array
                            ';' { "'$($param.Value)'" }
                            # Default - use as is
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
            # Return a blank record on error to maintain object count
            $Results += [PSCustomObject]@{
                Caller = "***"
                Cmdlet = "Error"
                FullCommand = "Error processing audit record: $_"
                'RunDate(UTC)' = $null
                ObjectModified = $null
                ResultStatus = "Error"
                WorkLoad = $null
                ClientIP = $null
                AppId = $null
                AppPoolName = $null
                ExternalAccess = $null
                OrganizationName = $null
                OriginatingServer = $null
                RequestId = $null
                SessionId = $null
            }
        }
    }

    End {
        $Results
    }
}