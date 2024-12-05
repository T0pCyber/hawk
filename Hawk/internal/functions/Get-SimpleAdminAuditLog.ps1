<#
.SYNOPSIS
    Convert output from Search-UnifiedAuditLog to be more human-readable.
.DESCRIPTION
    Parse and convert JSON-based AuditData field from Search-UnifiedAuditLog results.
.PARAMETER SearchResults
    Results from the Search-UnifiedAuditLog query.
.EXAMPLE
    PS C:\> Get-SimpleAdminAuditLog -SearchResults $results
.INPUTS
    Objects from Search-UnifiedAuditLog.
.OUTPUTS
    Human-readable audit log entries.
.NOTES
    Updated to handle JSON data from the AuditData field.
#>
Function Get-SimpleAdminAuditLog {
    Param (
        [Parameter(
            Position = 0,
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)
        ]
        $SearchResults
    )

    Begin {
        [array]$ResultSet = @()
    }

    Process {
        $SearchResults | ForEach-Object {
            $Result = New-Object PSObject

            # Parse the AuditData field if it exists
            if ($_.AuditData) {
                try {
                    $parsedAuditData = $_.AuditData | ConvertFrom-Json -ErrorAction Stop

                    # Extract fields from parsed AuditData
                    $CmdletName = $parsedAuditData.Operation
                    $Parameters = if ($parsedAuditData.Parameters) {
                        $parsedAuditData.Parameters | ForEach-Object {
                            if ($_ -is [PSCustomObject]) {
                                "$($_.Name): $($_.Value)"
                            } else {
                                $_
                            }
                        } -join "; "
                    } else {
                        "None"
                    }
                    $UserId = $parsedAuditData.UserId
                    $ObjectId = $parsedAuditData.ObjectId
                    $CreationDate = $parsedAuditData.CreationTime

                } catch {
                    Write-Warning "Failed to parse AuditData for record: $($_.AuditData)"
                    $CmdletName = "ParseError"
                    $Parameters = "ParseError"
                    $UserId = "Unknown"
                    $ObjectId = "Unknown"
                    $CreationDate = "Unknown"
                }
            } else {
                # Default values if AuditData is missing
                $CmdletName = "MissingAuditData"
                $Parameters = "None"
                $UserId = "Unknown"
                $ObjectId = "Unknown"
                $CreationDate = "Unknown"
            }

            # Build the result object
            $Result | Add-Member -MemberType NoteProperty -Value $CmdletName -Name Cmdlet
            $Result | Add-Member -MemberType NoteProperty -Value $Parameters -Name Parameters
            $Result | Add-Member -MemberType NoteProperty -Value $UserId -Name UserId
            $Result | Add-Member -MemberType NoteProperty -Value $ObjectId -Name ObjectId
            $Result | Add-Member -MemberType NoteProperty -Value $CreationDate -Name 'CreationDate(UTC)'

            $ResultSet += $Result
        }
    }

    End {
        Return $ResultSet
    }
}
