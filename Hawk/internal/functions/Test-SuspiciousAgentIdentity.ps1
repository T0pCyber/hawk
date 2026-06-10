Function Test-SuspiciousAgentIdentity {
    <#
    .SYNOPSIS
        Internal helper that flags Entra Agent ID identities warranting investigation.

    .DESCRIPTION
        Evaluates a normalized agent identity record (as produced by Get-HawkTenantAgentIdentity)
        and determines whether it exhibits properties that warrant analyst review, such as having no
        assigned owner (a possible shadow or orphaned agent), relying on password-secret credentials
        instead of certificates or federated identity credentials, or being disabled yet still
        present in the directory.

        Creation inside the current investigation window is recorded as supporting context on an
        already-flagged agent, but is not a trigger on its own - while Microsoft Entra Agent ID is
        new, every agent is recent, so recency alone is not a useful signal.

        The function returns a boolean and populates the supplied Reasons reference with a list of
        human-readable explanations for each match.

    .PARAMETER Agent
        The normalized agent identity object to evaluate. Expected properties include Owners,
        HasPasswordSecret, CreatedDateTime, and AccountEnabled.

    .PARAMETER Reasons
        A [ref] to an array that the function populates with the reasons the agent was flagged.

    .OUTPUTS
        System.Boolean. True when the agent identity matches one or more suspicious patterns.

    .EXAMPLE
        $reasons = @()
        $isSuspicious = Test-SuspiciousAgentIdentity -Agent $agentRecord -Reasons ([ref]$reasons)

        Evaluates $agentRecord and stores any flagging reasons in $reasons.

    .NOTES
        Internal helper used by Get-HawkTenantAgentIdentity.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [object]$Agent,

        [Parameter(Mandatory = $true)]
        [ref]$Reasons
    )

    $isSuspicious = $false
    $suspiciousReasons = @()

    # --- Triggers: genuine concerns that warrant investigation on their own ---

    # Orphaned / shadow agent: no owner assigned for accountability.
    if ([string]::IsNullOrEmpty($Agent.Owners)) {
        $isSuspicious = $true
        $suspiciousReasons += "no owner assigned (possible shadow or orphaned agent)"
    }

    # Password-secret credentials are discouraged for agents in favor of certificates or
    # federated identity credentials, and are a common persistence backdoor.
    if ($Agent.HasPasswordSecret) {
        $isSuspicious = $true
        $suspiciousReasons += "uses password-secret credential(s)"
    }

    # Disabled agent identity still present in the directory.
    if ($Agent.AccountEnabled -eq $false) {
        $isSuspicious = $true
        $suspiciousReasons += "agent identity is disabled but still present"
    }

    # --- Context (not a trigger): creation inside the investigation window is added as supporting
    # detail to an already-flagged agent, but does not flag an agent on its own. ---
    if ($isSuspicious -and $Agent.CreatedDateTime -and $Hawk.StartDate -and $Hawk.EndDate) {
        try {
            $created = [datetime]$Agent.CreatedDateTime
            if ($created -ge $Hawk.StartDate -and $created -le $Hawk.EndDate) {
                $suspiciousReasons += ("created within the investigation window (" + $created.ToString('yyyy-MM-dd') + ")")
            }
        }
        catch {
            # Unparseable creation date - ignore.
        }
    }

    $Reasons.Value = $suspiciousReasons
    return $isSuspicious
}
