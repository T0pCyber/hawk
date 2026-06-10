Function Get-HawkUserAIInteraction {
    <#
    .SYNOPSIS
        Collects Microsoft Copilot and AI application / agent interactions for specific users.

    .DESCRIPTION
        Searches the Microsoft 365 Unified Audit Log for Copilot and AI application activity
        attributed to the specified user(s). This shows which Copilot experiences and agents a user
        invoked, in which host applications, and which resources were accessed - valuable when
        investigating a potentially compromised account. Because delegated (on-behalf-of) agent
        activity is attributed to the user rather than the agent, this per-user view can surface
        risky agent-driven actions tied to a user session.

        The function aggregates the AI-related record types (CopilotInteraction,
        ConnectedAIAppInteraction, AIAppInteraction, and TeamCopilotInteraction) for each user,
        parses the audit data, and flags jailbreak attempts, third-party AI application use, and
        access to sensitivity-labeled resources. Output is written to each user's folder.

    .PARAMETER UserPrincipalName
        Single UPN of a user, a comma-separated list of UPNs, or an array of objects that contain
        UPNs, identifying which users to collect AI interaction activity for.

    .OUTPUTS
        File: AI_Interactions_<user>.csv / .json
        Path: \<User>
        Description: All Copilot and AI application interactions for the user in the search window.

        File: _Investigate_AI_Interactions_<user>.csv / .json
        Path: \<User>
        Description: Subset of the user's interactions flagged for investigation.

    .EXAMPLE
        Get-HawkUserAIInteraction -UserPrincipalName user@contoso.com

        Searches the Unified Audit Log for Copilot and AI application activity performed by
        user@contoso.com and writes the results to the user's output folder.

    .LINK
        https://learn.microsoft.com/en-us/purview/audit-copilot
    #>
    param
    (
        [Parameter(Mandatory = $true)]
        [array]$UserPrincipalName
    )

    # Check if Hawk object exists and is fully initialized
    if (Test-HawkGlobalObject) {
        Initialize-HawkGlobalObject
    }

    Test-EXOConnection
    Send-AIEvent -Event "CmdRun"

    # Verify our UPN input
    [array]$UserArray = Test-UserObject -ToTest $UserPrincipalName
    [array]$RecordTypes = "CopilotInteraction", "ConnectedAIAppInteraction", "AIAppInteraction", "TeamCopilotInteraction"

    foreach ($Object in $UserArray) {

        [string]$User = $Object.UserPrincipalName

        Out-LogFile "Initiating collection of Copilot and AI application activity for $User from the UAL." -Action

        [array]$AIEvents = $null
        foreach ($Type in $RecordTypes) {
            Out-LogFile ("Searching Unified Audit Log for AI interaction records of type: " + $Type) -Action
            try {
                $AIEvents += Get-AllUnifiedAuditLogEntry -UnifiedSearch ("Search-UnifiedAuditLog -UserIds " + $User + " -RecordType " + $Type)
            }
            catch {
                Out-LogFile ("Unable to search Unified Audit Log for record type " + $Type + ": " + $_.Exception.Message) -isError
            }
        }

        if ($null -eq $AIEvents -or $AIEvents.Count -eq 0) {
            Out-LogFile "No Copilot or AI application activity found for $User in the search time frame." -Information
            continue
        }

        Out-LogFile ("Found " + $AIEvents.Count + " Copilot/AI interaction records for $User. Parsing audit data.") -Information

        $parsed = @()
        foreach ($event in $AIEvents) {
            try {
                $data = $event.AuditData | ConvertFrom-Json
            }
            catch {
                continue
            }

            $accessedCount = 0
            $sensitivityLabels = $null
            if ($data.AccessedResources) {
                $accessedCount = ($data.AccessedResources | Measure-Object).Count
                $sensitivityLabels = (
                    $data.AccessedResources | ForEach-Object { $_.SensitivityLabelId } | Where-Object { $_ }
                ) -join ';'
            }

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
            $parsed | Out-MultipleFileType -FilePrefix "AI_Interactions" -User $User -csv -json
        }

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
            Out-LogFile ("Found " + $flaggedCount + " AI interactions for $User that warrant review (jailbreak attempts, third-party AI apps, or sensitivity-labeled resource access).") -Notice
            $flagged | Out-MultipleFileType -FilePrefix "_Investigate_AI_Interactions" -User $User -csv -json -Notice
        }

        Out-LogFile "Completed collection of Copilot and AI application activity for $User from the UAL." -Information
    }
}
