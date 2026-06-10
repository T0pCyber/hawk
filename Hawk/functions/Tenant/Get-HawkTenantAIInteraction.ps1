Function Get-HawkTenantAIInteraction {
    <#
    .SYNOPSIS
        Collects Microsoft Copilot and AI application / agent interaction events from the Unified Audit Log.

    .DESCRIPTION
        Searches the Microsoft 365 Unified Audit Log for Copilot and AI application activity across
        the tenant, including interactions with Microsoft Copilot, Copilot Studio agents, connected
        (registered) AI applications, third-party AI applications, and Teams Copilot. These events
        record who interacted with which agent or Copilot, in which host application, and which
        resources were accessed during the interaction.

        The function aggregates the AI-related record types (CopilotInteraction,
        ConnectedAIAppInteraction, AIAppInteraction, and TeamCopilotInteraction), parses the audit
        data, and flags interactions that warrant review: detected jailbreak attempts, interactions
        with third-party AI applications (a data egress concern), and interactions that accessed
        sensitivity-labeled resources.

    .OUTPUTS
        File: AI_Interactions.csv / .json
        Path: \Tenant
        Description: All Copilot and AI application interaction events found in the search window.

        File: _Investigate_AI_Interactions.csv / .json
        Path: \Tenant
        Description: Subset of interactions flagged for investigation.

    .EXAMPLE
        Get-HawkTenantAIInteraction

        Searches the Unified Audit Log for Copilot and AI application activity within the configured
        time window and writes the results to the Tenant output folder.

    .NOTES
        Author: Hawk Forensics

    .LINK
        https://learn.microsoft.com/en-us/purview/audit-copilot
    #>
    [CmdletBinding()]
    param()

    BEGIN {
        # Check if Hawk object exists and is fully initialized
        if (Test-HawkGlobalObject) {
            Initialize-HawkGlobalObject
        }

        Out-LogFile "Initiating collection of Copilot and AI application activity from the UAL." -Action

        Test-EXOConnection
        Send-AIEvent -Event "CmdRun"
    }

    PROCESS {
        # AI / agent interaction record types in the Unified Audit Log.
        [array]$RecordTypes = "CopilotInteraction", "ConnectedAIAppInteraction", "AIAppInteraction", "TeamCopilotInteraction"

        [array]$AIEvents = $null
        foreach ($Type in $RecordTypes) {
            Out-LogFile ("Searching Unified Audit Log for AI interaction records of type: " + $Type) -Action
            try {
                $AIEvents += Get-AllUnifiedAuditLogEntry -UnifiedSearch ("Search-UnifiedAuditLog -RecordType " + $Type)
            }
            catch {
                Out-LogFile ("Unable to search Unified Audit Log for record type " + $Type + ": " + $_.Exception.Message) -isError
            }
        }

        if ($null -eq $AIEvents -or $AIEvents.Count -eq 0) {
            Out-LogFile "No Copilot or AI application activity found in the search time frame." -Information
            return
        }

        Out-LogFile ("Found " + $AIEvents.Count + " Copilot/AI interaction records. Parsing audit data.") -Information

        $parsed = @()
        foreach ($event in $AIEvents) {
            try {
                $data = $event.AuditData | ConvertFrom-Json
            }
            catch {
                continue
            }

            # Summarize accessed resources and any sensitivity labels.
            $accessedCount = 0
            $sensitivityLabels = $null
            if ($data.AccessedResources) {
                $accessedCount = ($data.AccessedResources | Measure-Object).Count
                $sensitivityLabels = (
                    $data.AccessedResources | ForEach-Object { $_.SensitivityLabelId } | Where-Object { $_ }
                ) -join ';'
            }

            # Detect jailbreak attempts recorded on the prompt messages.
            $jailbreak = $false
            if ($data.Messages) {
                if ($data.Messages | Where-Object { $_.JailbreakDetected -eq $true }) {
                    $jailbreak = $true
                }
            }

            $parsed += [PSCustomObject]@{
                CreationTime      = $data.CreationTime
                RecordType        = $event.RecordType
                Operation         = $data.Operation
                Workload          = $data.Workload
                UserId            = $data.UserId
                AppIdentity       = $data.AppIdentity
                AppHost           = $data.AppHost
                AgentName         = $data.AgentName
                AgentVersion      = $data.AgentVersion
                AccessedResources = $accessedCount
                SensitivityLabels = $sensitivityLabels
                JailbreakDetected = $jailbreak
                ClientIP          = $data.ClientIP
            }
        }

        if ($parsed.Count -gt 0) {
            $parsed | Out-MultipleFileType -FilePrefix "AI_Interactions" -csv -json
        }

        # Flag interactions that warrant review.
        $flagged = $parsed | Where-Object {
            ($_.JailbreakDetected -eq $true) -or
            ($_.RecordType -eq 'ConnectedAIAppInteraction') -or
            ($_.RecordType -eq 'AIAppInteraction') -or
            ($_.Workload -eq 'ConnectedAIApp') -or
            ($_.Workload -eq 'AIApp') -or
            (-not [string]::IsNullOrEmpty($_.SensitivityLabels))
        }

        if ($flagged) {
            $flaggedCount = ($flagged | Measure-Object).Count
            Out-LogFile ("Found " + $flaggedCount + " AI interactions that warrant review (jailbreak attempts, third-party AI apps, or sensitivity-labeled resource access).") -Notice
            Out-LogFile "Please review _Investigate_AI_Interactions.csv for details." -Notice
            $flagged | Out-MultipleFileType -FilePrefix "_Investigate_AI_Interactions" -csv -json -Notice
        }
    }

    END {
        Out-LogFile "Completed collection of Copilot and AI application activity from the UAL." -Information
    }
}
