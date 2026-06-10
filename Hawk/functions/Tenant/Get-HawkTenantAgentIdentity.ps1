Function Get-HawkTenantAgentIdentity {
    <#
    .SYNOPSIS
        Collects Microsoft Entra Agent ID (AI agent) identities and flags those warranting review.

    .DESCRIPTION
        Enumerates Microsoft Entra Agent ID agent identities in the tenant using the Microsoft Graph
        agentIdentity service principal cast (GET /servicePrincipals/microsoft.graph.agentIdentity).
        AI agents - such as those created by Microsoft Copilot Studio and managed through Microsoft
        Agent 365 - are represented as a dedicated service principal subtype in Microsoft Entra, so
        this function gives responders an inventory of the agent identity attack surface alongside
        Hawk's existing application and service principal collection.

        For each agent identity the function records core directory properties, a credential
        summary, and resolved owners, then flags agents that warrant review (no owner,
        password-secret credentials, creation inside the investigation window, or
        disabled-but-present) using the Test-SuspiciousAgentIdentity helper.

        The function degrades gracefully: if the agent identity endpoint is not available in the
        tenant, or the AgentIdentity.Read.All permission has not been consented, it logs an
        informational message and returns without error.

    .OUTPUTS
        File: AgentIdentities.csv / .json
        Path: \Tenant
        Description: Inventory of all Entra Agent ID agent identities and their properties.

        File: _Investigate_AgentIdentities.csv / .json
        Path: \Tenant
        Description: Subset of agent identities flagged for investigation, with reasons.

    .EXAMPLE
        Get-HawkTenantAgentIdentity

        Enumerates all Entra Agent ID agent identities in the tenant and writes the inventory and any
        flagged agents to the Tenant output folder.

    .NOTES
        Requires the following Microsoft Graph permission:
        - AgentIdentity.Read.All

    .LINK
        https://learn.microsoft.com/en-us/graph/api/agentidentity-list
    #>
    [CmdletBinding()]
    param()

    BEGIN {
        # Check if Hawk object exists and is fully initialized
        if (Test-HawkGlobalObject) {
            Initialize-HawkGlobalObject
        }

        # Create Tenant folder path if it doesn't exist
        $tenantPath = Join-Path -Path $Hawk.FilePath -ChildPath "Tenant"
        if (-not (Test-Path -Path $tenantPath)) {
            New-Item -Path $tenantPath -ItemType Directory -Force | Out-Null
        }

        Out-LogFile "Initiating collection of Entra Agent ID identities from Microsoft Graph." -Action

        Test-GraphConnection
        Send-AIEvent -Event "CmdRun"
    }

    PROCESS {
        try {
            # Enumerate agent identities (a service principal subtype). GA on the v1.0 endpoint.
            $agentUri = "https://graph.microsoft.com/v1.0/servicePrincipals/microsoft.graph.agentIdentity"
            $agents = Get-HawkAllGraphResult -Uri $agentUri

            if ($null -eq $agents) {
                Out-LogFile "Entra Agent ID identities are not available in this tenant, or the AgentIdentity.Read.All permission has not been consented. Skipping." -Information
                return
            }

            if ($agents.Count -eq 0) {
                Out-LogFile "No Entra Agent ID identities found in the tenant." -Information
                return
            }

            Out-LogFile ("Found " + $agents.Count + " agent identities. Processing details.") -Information

            $agentResults = @()
            foreach ($agent in $agents) {

                # Resolve owners so we can spot orphaned / shadow agents.
                $ownerNames = $null
                if ($agent.id) {
                    $owners = Get-HawkAllGraphResult -Uri ("https://graph.microsoft.com/v1.0/servicePrincipals/" + $agent.id + "/owners")
                    if ($owners) {
                        $ownerNames = (
                            $owners | ForEach-Object {
                                if ($_.userPrincipalName) { $_.userPrincipalName } else { $_.displayName }
                            }
                        ) -join ';'
                    }
                }

                $passwordCount = ($agent.passwordCredentials | Measure-Object).Count
                $keyCount = ($agent.keyCredentials | Measure-Object).Count

                $agentResults += [PSCustomObject]@{
                    DisplayName             = $agent.displayName
                    Id                      = $agent.id
                    AppId                   = $agent.appId
                    ServicePrincipalType    = $agent.servicePrincipalType
                    AgentType               = $agent.agentType
                    BlueprintId             = $agent.blueprintId
                    AccountEnabled          = $agent.accountEnabled
                    CreatedDateTime         = $agent.createdDateTime
                    Owners                  = $ownerNames
                    HasPasswordSecret       = ($passwordCount -gt 0)
                    HasKeyCredential        = ($keyCount -gt 0)
                    PasswordCredentialCount = $passwordCount
                    KeyCredentialCount      = $keyCount
                }
            }

            # Write the full inventory
            $agentResults | Out-MultipleFileType -FilePrefix "AgentIdentities" -csv -json

            # Flag agents that warrant review
            $flagged = @()
            foreach ($record in $agentResults) {
                $reasons = @()
                if (Test-SuspiciousAgentIdentity -Agent $record -Reasons ([ref]$reasons)) {
                    $flagged += ($record | Select-Object -Property *, @{Name = 'InvestigateReasons'; Expression = { $reasons -join '; ' } })
                }
            }

            if ($flagged.Count -gt 0) {
                Out-LogFile ("Found " + $flagged.Count + " agent identities that warrant review (orphaned, secret-based, newly created, or disabled).") -Notice
                Out-LogFile "Please review _Investigate_AgentIdentities.csv to ensure these agent identities are expected." -Notice
                $flagged | Out-MultipleFileType -FilePrefix "_Investigate_AgentIdentities" -csv -json -Notice
            }
        }
        catch {
            Out-LogFile "Error collecting Entra Agent ID identities: $($_.Exception.Message)" -isError
            Write-Error -ErrorRecord $_ -ErrorAction Continue
        }
    }

    END {
        Out-LogFile "Completed collection of Entra Agent ID identities from Microsoft Graph." -Information
    }
}
