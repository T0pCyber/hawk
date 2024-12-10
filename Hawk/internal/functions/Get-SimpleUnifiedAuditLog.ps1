function Get-SimpleUnifiedAuditLog {
    <#
    .SYNOPSIS
        Formats unified audit log records into a flat structure for analysis.

    .DESCRIPTION
        Processes unified audit log records by extracting all properties from both the base record
        and the nested AuditData JSON. It flattens nested objects like AppAccessContext and Parameters
        into individual columns, making the data easier to analyze in CSV format.

        The function handles:
        - Base record properties
        - Nested AuditData JSON
        - Parameter arrays
        - AppAccessContext data
        - Full command reconstruction
        - Error cases with appropriate logging

    .PARAMETER Record
        A PowerShell object representing a unified audit log record. This should be the output
        from Search-UnifiedAuditLog and should contain both base properties and an AuditData
        property containing a JSON string of additional audit information.

    .EXAMPLE
        $auditLogs = Search-UnifiedAuditLog -StartDate $startDate -EndDate $endDate -RecordType ExchangeAdmin
        $auditLogs | Get-SimpleUnifiedAuditLog

        Processes Exchange admin audit logs, expanding all properties into a flat structure.

    .EXAMPLE
        $userChanges = Search-UnifiedAuditLog -UserIds user@domain.com -Operations "Add-*"
        $userChanges | Get-SimpleUnifiedAuditLog | Export-Csv -Path "UserChanges.csv" -NoTypeInformation

        Gets all "Add" operations for a specific user and exports the processed results to CSV.

    .OUTPUTS
        Outputs a collection of PSCustomObjects with flattened properties from the audit logs.
        Each object contains:
        - Base record properties (RecordType, CreationDate, etc.)
        - Expanded AuditData properties
        - Individual parameter columns prefixed with "Param_"
        - Consolidated parameter view
        - Formatted full command string
        - AppAccessContext data in separate columns

    .NOTES
        The function focuses on complete data visibility by exposing all available properties
        from the audit logs. This helps administrators and security professionals analyze
        the full context of audit events for incident response and compliance purposes.
    #>
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
                    # Common Schema properties
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