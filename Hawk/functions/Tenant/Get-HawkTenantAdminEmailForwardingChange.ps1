Function Get-HawkTenantAdminEmailForwardingChange {
    <#
    .SYNOPSIS
        Retrieves audit log entries for email forwarding changes made within the tenant.

    .DESCRIPTION
        This function queries the Microsoft 365 Unified Audit Log for events related to email
        forwarding configuration changes (Set-Mailbox with forwarding parameters). It focuses on
        tracking when and by whom forwarding rules were added or modified, helping identify potential
        unauthorized data exfiltration attempts.

        Key points:
        - Monitors changes to both ForwardingAddress and ForwardingSMTPAddress settings
        - Resolves recipient information for ForwardingAddress values
        - Flags all forwarding changes for review as potential security concerns
        - Provides historical context for forwarding configuration changes

    .OUTPUTS
        File: Simple_Forwarding_Changes.csv/.json
        Path: \Tenant
        Description: Simplified view of forwarding configuration changes.

        File: Forwarding_Changes.csv/.json
        Path: \Tenant
        Description: Detailed audit log data for forwarding changes.

        File: Forwarding_Recipients.csv/.json
        Path: \Tenant
        Description: List of unique forwarding destinations configured.

    .EXAMPLE
        Get-HawkTenantAdminEmailForwardingChange

        Retrieves all email forwarding configuration changes from the audit logs within the specified
        search window.
    #>
    [CmdletBinding()]
    param()

    # Test the Exchange Online connection to ensure the environment is ready for operations.
    Test-EXOConnection
    # Log the execution of the function for audit and telemetry purposes.
    Send-AIEvent -Event "CmdRun"

    # Initialize timing variables for status updates
    $startTime = Get-Date
    $lastUpdate = $startTime

    # Log the start of the analysis process for email forwarding configuration changes.
    Out-LogFile "Analyzing email forwarding configuration changes from audit logs" -Action

    # Ensure the tenant-specific folder exists to store output files. If not, create it.
    $TenantPath = Join-Path -Path $Hawk.FilePath -ChildPath "Tenant"
    if (-not (Test-Path -Path $TenantPath)) {
        New-Item -Path $TenantPath -ItemType Directory -Force | Out-Null
    }

    try {
        # Define both operations and broader search terms to cast a wider net.
        $searchCommand = @"
Search-UnifiedAuditLog -RecordType ExchangeAdmin -Operations @(
    'Set-Mailbox',
    'Set-MailUser',
    'Set-RemoteMailbox',
    'Enable-RemoteMailbox'
)
"@

        # Fetch all specified operations from the audit log
        [array]$AllMailboxChanges = Get-AllUnifiedAuditLogEntry -UnifiedSearch $searchCommand

        # Log search completion time
        Out-LogFile "Unified Audit Log search completed" -Information

        Out-LogFile "Filtering results for forwarding changes..." -Action

        # Enhanced filtering to catch more types of forwarding changes
        [array]$ForwardingChanges = $AllMailboxChanges | Where-Object {
            $auditData = $_.AuditData | ConvertFrom-Json
            $parameters = $auditData.Parameters
            ($parameters | Where-Object {
                $_.Name -in @(
                    'ForwardingAddress',
                    'ForwardingSMTPAddress',
                    'ExternalEmailAddress',
                    'PrimarySmtpAddress',
                    'RedirectTo',             # Added from other LLM suggestion
                    'DeliverToMailboxAndForward',  # Corrected parameter name
                    'DeliverToAndForward'     # Alternative parameter name
                ) -or
                # Check for parameter changes enabling forwarding
                ($_.Name -eq 'DeliverToMailboxAndForward' -and $_.Value -eq 'True') -or
                ($_.Name -eq 'DeliverToAndForward' -and $_.Value -eq 'True')
            })
        }

        Out-LogFile "Completed filtering for forwarding changes" -Information

        if ($ForwardingChanges.Count -gt 0) {
            # Log the number of forwarding configuration changes found.
            Out-LogFile ("Found " + $ForwardingChanges.Count + " change(s) to user email forwarding") -Information

            # Write raw JSON data for detailed reference and potential troubleshooting.
            $RawJsonPath = Join-Path -Path $TenantPath -ChildPath "Forwarding_Changes_Raw.json"
            $ForwardingChanges | Select-Object -ExpandProperty AuditData | Out-File -FilePath $RawJsonPath

            # Parse the audit data into a simpler format for further processing and output.
            $ParsedChanges = $ForwardingChanges | Get-SimpleUnifiedAuditLog
            if ($ParsedChanges) {
                # Write the simplified data for quick analysis and review.
                $ParsedChanges | Out-MultipleFileType -FilePrefix "Simple_Forwarding_Changes" -csv -json -Notice

                # Write the full audit log data for comprehensive records.
                $ForwardingChanges | Out-MultipleFileType -FilePrefix "Forwarding_Changes" -csv -json -Notice

                # Initialize an array to store processed forwarding destination data.
                $ForwardingDestinations = @()

                Out-LogFile "Beginning detailed analysis of forwarding changes..." -Action
                foreach ($change in $ParsedChanges) {
                    # Add a status update every 30 seconds
                    $currentTime = Get-Date
                    if (($currentTime - $lastUpdate).TotalSeconds -ge 30) {
                        Out-LogFile "Processing forwarding changes... ($($ForwardingDestinations.Count) destinations found so far)" -Action
                        $lastUpdate = $currentTime
                    }

                    $targetUser = $change.ObjectId

                    # Process ForwardingSMTPAddress changes if detected in the audit log.
                    if ($change.Parameters -match "ForwardingSMTPAddress") {
                        $smtpAddress = ($change.Parameters | Select-String -Pattern "ForwardingSMTPAddress:\s*([^,]+)").Matches.Groups[1].Value
                        if ($smtpAddress) {
                            # Add the SMTP forwarding configuration to the destinations array.
                            $ForwardingDestinations += [PSCustomObject]@{
                                UserModified = $targetUser
                                TargetSMTPAddress = $smtpAddress.Split(":")[-1].Trim() # Remove "SMTP:" prefix if present.
                                ChangeType = "SMTP Forwarding"
                                ModifiedBy = $change.UserId
                                ModifiedTime = $change.CreationTime
                            }
                        }
                    }

                    # Process ForwardingAddress changes if detected in the audit log.
                    if ($change.Parameters -match "ForwardingAddress") {
                        $forwardingAddress = ($change.Parameters | Select-String -Pattern "ForwardingAddress:\s*([^,]+)").Matches.Groups[1].Value
                        if ($forwardingAddress) {
                            try {
                                # Attempt to resolve the recipient details from Exchange Online.
                                $recipient = Get-EXORecipient $forwardingAddress -ErrorAction Stop

                                # Determine the recipient's type and extract the appropriate address.
                                $targetAddress = switch ($recipient.RecipientType) {
                                    "MailContact" { $recipient.ExternalEmailAddress.Split(":")[-1] }
                                    default { $recipient.PrimarySmtpAddress }
                                }

                                # Add the recipient forwarding configuration to the destinations array.
                                $ForwardingDestinations += [PSCustomObject]@{
                                    UserModified = $targetUser
                                    TargetSMTPAddress = $targetAddress
                                    ChangeType = "Recipient Forwarding"
                                    ModifiedBy = $change.UserId
                                    ModifiedTime = $change.CreationTime
                                }
                            }
                            catch {
                                # Log a warning if the recipient cannot be resolved.
                                Out-LogFile "Unable to resolve forwarding recipient: $forwardingAddress" -Notice
                                # Add an unresolved entry for transparency in the output.
                                $ForwardingDestinations += [PSCustomObject]@{
                                    UserModified = $targetUser
                                    TargetSMTPAddress = "UNRESOLVED:$forwardingAddress"
                                    ChangeType = "Recipient Forwarding (Unresolved)"
                                    ModifiedBy = $change.UserId
                                    ModifiedTime = $change.CreationTime
                                }
                            }
                        }
                    }
                }


                Out-LogFile "Completed processing forwarding changes" -Information

                if ($ForwardingDestinations.Count -gt 0) {
                    # Log the total number of forwarding destinations detected.
                    Out-LogFile ("Found " + $ForwardingDestinations.Count + " forwarding destinations configured") -Information
                    # Write the forwarding destinations data to files for review.
                    $ForwardingDestinations | Out-MultipleFileType -FilePrefix "Forwarding_Recipients" -csv -json -Notice

                    # Log details about each forwarding destination for detailed auditing.
                    foreach ($dest in $ForwardingDestinations) {
                        Out-LogFile "Forwarding configured: $($dest.UserModified) -> $($dest.TargetSMTPAddress) ($($dest.ChangeType)) by $($dest.ModifiedBy) at $($dest.ModifiedTime)" -Notice
                    }
                }
            }
            else {
                # Log a warning if the parsing of audit data fails.
                Out-LogFile "Error: Failed to parse forwarding change audit data" -Notice
            }
        }
        else {
            # Log a message if no forwarding changes are found in the logs.
            Out-LogFile "No forwarding changes found in filtered results" -Information
            Out-LogFile "Retrieved $($AllMailboxChanges.Count) total operations, but none involved forwarding changes" -Information
        }
    }
    catch {
        # Log an error if the analysis encounters an exception.
        Out-LogFile "Error analyzing email forwarding changes: $($_.Exception.Message)" -Notice
        Write-Error -ErrorRecord $_ -ErrorAction Continue
    }
}
           
