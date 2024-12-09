function Get-SimpleUnifiedAuditLog {
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
                # Create hashtable for all properties
                $properties = @{
                    # Base record properties
                    RecordType = $Record.RecordType
                    CreationDate = $Record.CreationDate
                    UserIds = $Record.UserIds
                    Operations = $Record.Operations
                    ResultIndex = $Record.ResultIndex
                    ResultCount = $Record.ResultCount
                    Identity = $Record.Identity
                    IsValid = $Record.IsValid
                    ObjectState = $Record.ObjectState

                    # AppAccessContext properties
                    AADSessionId = $AuditData.AppAccessContext.AADSessionId
                    AppAccessContextIssuedAtTime = $AuditData.AppAccessContext.IssuedAtTime
                    AppAccessContextUniqueTokenId = $AuditData.AppAccessContext.UniqueTokenId

                    # Common AuditData properties
                    AuditCreationTime = $AuditData.CreationTime
                    AuditId = $AuditData.Id
                    Operation = $AuditData.Operation
                    OrganizationId = $AuditData.OrganizationId
                    AuditRecordType = $AuditData.RecordType
                    ResultStatus = $AuditData.ResultStatus
                    UserKey = $AuditData.UserKey
                    UserType = $AuditData.UserType
                    Version = $AuditData.Version
                    Workload = $AuditData.Workload
                    ClientIP = $AuditData.ClientIP
                    ObjectId = $AuditData.ObjectId
                    UserId = $AuditData.UserId
                    AppId = $AuditData.AppId
                    AppPoolName = $AuditData.AppPoolName
                    ClientAppId = $AuditData.ClientAppId
                    CorrelationID = $AuditData.CorrelationID
                    ExternalAccess = $AuditData.ExternalAccess
                    OrganizationName = $AuditData.OrganizationName
                    OriginatingServer = $AuditData.OriginatingServer
                    RequestId = $AuditData.RequestId
                    SessionId = $AuditData.SessionId
                    DeviceId = $AuditData.DeviceId
                }

                # Add each parameter as its own column
                if ($AuditData.Parameters) {
                    foreach ($param in $AuditData.Parameters) {
                        $properties["Param_$($param.Name)"] = $param.Value
                    }

                    # Also add consolidated parameters view
                    $properties["Parameters"] = ($AuditData.Parameters | ForEach-Object {
                        "$($_.Name)=$($_.Value)"
                    }) -join ' | '
                }

                # Create full command string
                if ($AuditData.Parameters) {
                    $paramStrings = foreach ($param in $AuditData.Parameters) {
                        $value = switch -Regex ($param.Value) {
                            '\s' { "'$($param.Value)'" }
                            '^True$|^False$' { "`$$($param.Value.ToLower())" }
                            ';' { "'$($param.Value)'" }
                            default { $param.Value }
                        }
                        "-$($param.Name) $value"
                    }
                    $properties["FullCommand"] = "$($AuditData.Operation) $($paramStrings -join ' ')"
                }
                else {
                    $properties["FullCommand"] = $AuditData.Operation
                }

                # Check for any other properties in AuditData and add them
                foreach ($prop in $AuditData.PSObject.Properties) {
                    if (-not $properties.ContainsKey($prop.Name) -and $prop.Name -ne 'Parameters' -and $prop.Name -ne 'AppAccessContext') {
                        $properties[$prop.Name] = $prop.Value
                    }
                }

                $Results += [PSCustomObject]$properties
            }
        }
        catch {
            Write-Verbose "Error processing record: $_"
            $Results += [PSCustomObject]@{
                RecordType = "Error"
                CreationDate = Get-Date
                UserIds = "Error"
                Operations = "Error processing audit record: $_"
                ResultIndex = 0
                ResultCount = 0
                Identity = "Error"
                IsValid = $false
                ObjectState = "Error"
                ErrorDetails = $_.Exception.Message
            }
        }
    }

    End {
        $Results
    }
}