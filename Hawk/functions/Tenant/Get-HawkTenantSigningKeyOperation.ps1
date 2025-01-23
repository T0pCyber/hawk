Function Get-HawkTenantSigningKeyOperation {
    <#
    .SYNOPSIS
        Retrieves Microsoft Entra ID signing key operation events from Graph activity logs.

    .DESCRIPTION
        This function collects audit logs for signing key operations in Microsoft Entra ID using the Microsoft 
        Graph API. It focuses on security-critical key operations including:
        - Key rotation events
        - Key creation events
        - Key invalidation events

        The function helps identify potentially malicious key operations that could indicate 
        compromise, similar to the 2023 Microsoft Entra ID signing key incident.

        All events are collected within the date range specified in the Hawk configuration.

    .OUTPUTS
        File: SigningKeyOperations.csv/.json
        Path: \Tenant
        Description: All signing key operations detected within the specified time range

        File: _Investigate_SigningKeyOperations.csv/.json
        Path: \Tenant
        Description: Suspicious or high-risk signing key operations requiring investigation

    .EXAMPLE
        Get-HawkTenantSigningKeyOperation

        Retrieves all signing key operations from the Graph activity logs within the configured time window.

    .NOTES
        This function requires the following Graph API permissions:
        - AuditLog.Read.All
        - Directory.Read.All

        The results can help identify potential security issues like:
        - Unexpected key rotations
        - Unauthorized key creation
        - Suspicious invalidation patterns
        - Key operations from unusual sources

        Author: Jonathan Butler
        Last Updated: January 2025
    #>
    [CmdletBinding()]
    param()

    BEGIN {
        # Check if Hawk object exists and is fully initialized
        if (Test-HawkGlobalObject) {
            Initialize-HawkGlobalObject
        }


        # Verify Graph connection
        Test-GraphConnection

    }

    PROCESS {
        try {
            # Define the key operation types we want to monitor
            $keyOperations = @(
                "Update key",
                "Create key",
                "Invalidate key",
                "Rotate key"
            )

            # Build filter for the date range
            $startDate = $Hawk.StartDate.ToString("yyyy-MM-ddTHH:mm:ssZ")
            $endDate = $Hawk.EndDate.ToString("yyyy-MM-ddTHH:mm:ssZ")

            # Query for key operations.
            $keyEvents = Get-MgAuditLogDirectoryAudit -Filter "activityDateTime ge $startDate and activityDateTime le $endDate" -All |
                Where-Object { 
                    $_.ActivityDisplayName -in $keyOperations -or
                    $_.Category -eq 'KeyManagement'
                }

            if ($null -eq $keyEvents -or $keyEvents.Count -eq 0) {
                Out-LogFile "No signing key operations found in the specified time range." -Information
                return
            }

            Out-LogFile ("Found " + $keyEvents.Count + " signing key operations") -Information

            # Process each event into a custom object for export
            $processedEvents = $keyEvents | ForEach-Object {
                # Extract actor details
                $actorDetails = if ($_.InitiatedBy.User) {
                    $_.InitiatedBy.User.UserPrincipalName
                } elseif ($_.InitiatedBy.App) {
                    "App: " + $_.InitiatedBy.App.DisplayName
                } else {
                    "Unknown"
                }

                # Create processed event object
                [PSCustomObject]@{
                    TimeStamp = $_.ActivityDateTime
                    Operation = $_.ActivityDisplayName
                    Actor = $actorDetails
                    Result = $_.Result
                    CorrelationId = $_.CorrelationId
                    Category = $_.Category
                    Risk = if ($_.ResultReason -like "*unexpected*" -or 
                             $_.ResultReason -like "*unauthorized*" -or
                             $_.ActivityDisplayName -like "*invalidate*") { "High" } else { "Normal" }
                    AdditionalDetails = $_.AdditionalDetails | ConvertTo-Json -Compress
                    TargetResources = $_.TargetResources | ConvertTo-Json -Compress
                }
            }

            # Export all events
            $processedEvents | Out-MultipleFileType -FilePrefix "SigningKeyOperations" -csv -json

            # Identify and export suspicious events
            $suspiciousEvents = $processedEvents | Where-Object {
                $_.Risk -eq "High" -or
                $_.Actor -notlike "*@*.onmicrosoft.com" -or  # Non-standard admin accounts
                $_.Result -eq "Failure" -or                  # Failed operations could indicate attempts
                $_.Actor -like "App:*"                       # App-based key operations are unusual
            }

            if ($suspiciousEvents) {
                Out-LogFile "Found suspicious signing key operations requiring investigation" -Notice
                $suspiciousEvents | Out-MultipleFileType -FilePrefix "_Investigate_SigningKeyOperations" -csv -json -Notice

                # Log details about suspicious events
                foreach ($event in $suspiciousEvents) {
                    Out-LogFile "Suspicious key operation detected:" -Notice
                    Out-LogFile "  Time: $($event.TimeStamp)" -Notice
                    Out-LogFile "  Operation: $($event.Operation)" -Notice
                    Out-LogFile "  Actor: $($event.Actor)" -Notice
                    Out-LogFile "  Risk Level: $($event.Risk)" -Notice
                }
            }
        }
        catch {
            Out-LogFile "Error collecting signing key operations: $($_.Exception.Message)" -isError
            Write-Error -ErrorRecord $_ -ErrorAction Continue
        }
    }

    END {
        Out-LogFile "Completed gathering signing key operations" -Information
    }
}