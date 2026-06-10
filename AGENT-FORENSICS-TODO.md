# TODO — Agent-identity forensic collectors (Graph-only, no UAL)

**Branch:** `feature/agent-identity-collectors`

**Why this list:** The agentic pilot on this branch added `Get-HawkTenantAgentIdentity`
(Entra Agent ID inventory) plus the Copilot/AI activity collectors. **This tenant cannot
enable the Unified Audit Log**, so the UAL-based collectors (`Get-HawkTenantAIInteraction`,
`Get-HawkUserAIInteraction`) return nothing here. Everything below uses **Microsoft Graph
only — do NOT call `Search-UnifiedAuditLog`.** Items are in priority order.

## Conventions (apply to every item)

- **Graph access:** use the existing helper `Hawk/internal/functions/Get-HawkAllGraphResult.ps1`
  (handles paging + `Prefer: include-unknown-enum-members` + graceful 4xx → `$null`). Pass it a
  full URI; use `/beta` where noted.
- **Skeleton:** copy `Hawk/functions/Tenant/Get-HawkTenantAgentIdentity.ps1` — BEGIN: init `$Hawk`,
  `Test-GraphConnection`, `Send-AIEvent`; PROCESS: collect → `Out-MultipleFileType -csv -json`,
  flag with `Out-LogFile -Notice` + a `_Investigate_*` file (model the flag logic on
  `internal/functions/Test-SuspiciousAgentIdentity.ps1`); always degrade gracefully
  ("not available" / "none found"); END.
- **Scope by inventory:** most items should take the agent list (object IDs + appIds) from
  `Get-HawkTenantAgentIdentity` to target their queries.
- **Register + wire:** add each public function to `Hawk/Hawk.psd1` `FunctionsToExport` and into
  `Hawk/functions/Tenant/Start-HawkTenantInvestigation.ps1`.
- **CI gotchas:** full comment-based help is mandatory (Help/Manifest Pester tests fail without it);
  new `.ps1` files **including `*.Tests.ps1` need a UTF-8 BOM**; run Pester on **Windows PowerShell
  5.1** — pwsh 7.4 false-fails every `[CmdletBinding()]` function on `ProgressAction`.

---

## P1 — Agent directory audit events  (`Get-HawkTenantAgentAuditLog`)
**Forensic value:** Highest persistence/tampering signal without the UAL — credential adds, new
consent, permission/role changes, and create/delete on agent identities and their blueprints.
**Source (Graph, GA v1.0; agent fields on /beta):** `GET /v1.0/auditLogs/directoryAudits`
(30-day retention). Filter to events whose `targetResources[].id` is an inventory agent/blueprint
ID, or by `activityDisplayName` (*Add service principal*, *Add application*, *Add service principal
credentials*, *Consent to application*, *Add app role assignment to service principal*). On `/beta`
also filter `initiatedBy/app/agentType ne 'notAgentic'` and read `blueprintId`.
**Model after:** `Get-HawkTenantEntraIDAuditLog.ps1` (uses `Get-MgAuditLogDirectoryAudit`; prefer
`Get-HawkAllGraphResult` for the beta agent fields).
**Flag (`_Investigate_`):** credential added to an agent/blueprint; new consent or app-role grant;
agent created/deleted in the window; actor is itself an agent (agent-creates-agent).
**Output:** `AgentAuditLogs.csv/.json`, `_Investigate_AgentAuditLogs.*`.
**Note:** 30-day cap is a Graph limit — warn if the Hawk window exceeds it (the model function does).

## P2 — Agent sign-in activity  (`Get-HawkTenantAgentSignInLog`)
**Forensic value:** The primary "what are the agents doing" signal without the UAL — when/where
agents authenticate, failures, spikes, Conditional Access outcomes, source IPs and target resources.
**Source (Graph; service-principal sign-ins GA, agent filter on /beta):**
`GET /beta/auditLogs/signIns?$filter=signInEventTypes/any(t: t eq 'servicePrincipal') and agent/agentType eq 'AgentIdentity'`.
Fallback that needs no beta agent filter: loop the inventory appIds and query
`signIns?$filter=appId eq '<appId>'`. Capture `createdDateTime, appId, servicePrincipalId,
ipAddress, resourceDisplayName, status, conditionalAccessStatus, tokenIssuerType`.
**Model after:** `Get-HawkUserEntraIDSignInLog.ps1` (uses `Get-MgAuditLogSignIn`).
**Flag:** failed sign-ins; sign-in spike vs the agent's own baseline; access to unfamiliar
resources; `conditionalAccessStatus` of `failure`/`notApplied`.
**Output:** `AgentSignInLogs.csv/.json`, `_Investigate_AgentSignInLogs.*`.

## P3 — Agent blueprint & credential / FIC inventory  (`Get-HawkTenantAgentBlueprint`)
**Forensic value:** Closes a real gap. Agent *instances* carry no credentials of their own
(confirmed in this tenant: every agent had `HasPasswordSecret/HasKeyCredential = False`), so the
actual credential/persistence surface lives on the **blueprint**. This is where a backdoor secret,
cert, or federated-trust would be planted.
**Source (Graph):** enumerate blueprints `GET /v1.0/applications/microsoft.graph.agentIdentityBlueprint`
and blueprint principals `GET /v1.0/servicePrincipals/microsoft.graph.agentIdentityBlueprintPrincipal`
(verify exact casts at build time). For each blueprint pull `passwordCredentials`, `keyCredentials`,
and **`GET /applications/{id}/federatedIdentityCredentials`** (the FIC trusts that let other
identities impersonate the agent).
**Model after:** `Get-HawkTenantAppAndSPNCredentialDetail.ps1` (credential flattening w/ start/end dates).
**Flag:** password secret on a blueprint (discouraged); any credential or FIC added inside the
window (persistence); FIC issuer/subject that is unexpected.
**Output:** `AgentBlueprints.csv/.json`, `AgentBlueprintCredentials.csv/.json`,
`_Investigate_AgentBlueprintCredentials.*`.

## P4 — Agent permission / over-privilege report  (`Get-HawkTenantAgentPermission`)
**Forensic value:** Blast radius — what each agent can actually do; over-privileged agents are the
high-impact-if-compromised set.
**Source (Graph):** per inventory agent, `GET /servicePrincipals/{id}/appRoleAssignments`
(application permissions granted to the agent) and `/oauth2PermissionGrants` (delegated). Resolve
appRole IDs → permission names against the resource SP (e.g. Microsoft Graph).
**Model after:** `Get-HawkTenantConsentGrant.ps1` + `internal/functions/Get-AzureADPSPermission.ps1`
— **reuse its high-risk regex** (`*.ReadWrite.All`, `RoleManagement.ReadWrite.Directory`, `Mail.*`,
`Files.*`, `Sites.*`, `Directory.ReadWrite.All`, etc.).
**Flag:** any high-risk/broad scope held by an agent; agent granted Directory/RoleManagement write.
**Output:** `AgentPermissions.csv/.json`, `_Investigate_AgentPermissions.*`.

## P5 — Risky agents (Entra ID Protection)  (`Get-HawkTenantRiskyAgent`)
**Forensic value:** Microsoft-generated risk on agents — unfamiliar resource access, sign-in spikes,
failed access, admin-confirmed compromise, threat intel.
**Source (Graph /beta; requires Entra ID P2 — Preview):** agent risk detections via Identity
Protection (e.g. `GET /beta/identityProtection/riskDetections` filtered to agents, or the dedicated
agent-risk collection — **confirm the exact endpoint at build time**). riskEventTypes:
`unfamiliarResourceAccess`, `signInSpike`, `failedAccessAttempt`, `adminConfirmedAgentCompromised`,
`threatIntelligenceAccount`.
**Model after:** `Get-HawkTenantRiskDetections.ps1` / `Get-HawkTenantRiskyUsers.ps1`.
**Flag:** any detection; separate "confirmed compromised". **Degrade gracefully** when the tenant
has no P2 / the feature is off.
**Output:** `RiskyAgents.csv/.json`, `_Investigate_RiskyAgents.*`.
**Note:** in OBO (on-behalf-of) flows risk is attributed to the *user*, not the agent — say so in help.

## P6 — Ownership & sponsorship governance  (enrich inventory, or `Get-HawkTenantAgentOwnership`)
**Forensic value:** Accountability — Entra Agent ID expects a human **sponsor** per agent. In this
tenant several agents are owned by a Foundry *project* path, not a person.
**Source (Graph):** `GET /servicePrincipals/{id}/owners`; the **sponsor** relationship (confirm the
property/endpoint at build time).
**Flag:** no owner at all (already covered); **owner present but no human UPN** (no `@`) → "no human
sponsor"; sponsor missing.
**Output:** add `Sponsors` / `HasHumanOwner` columns to `AgentIdentities.*`; flag the no-human-sponsor
set into `_Investigate_AgentIdentities.*`.

## P7 — Enrich AgentType / BlueprintId on the inventory
**Forensic value:** Correlate each agent **instance → its blueprint**; surface orphaned instances
whose blueprint was deleted.
**Source (Graph /beta or `$select`/`$expand`):** the v1.0 `agentIdentity` cast returns empty
`agentType`/`blueprintId`; pull them from `/beta` or via `$select=appId,blueprintId,agentType` /
`$expand`. **Confirm the property path at build time.**
**Model after:** extend `Get-HawkTenantAgentIdentity.ps1`.
**Flag:** instance whose `blueprintId` has no matching blueprint (orphaned/dangling).

## P8 — Conditional Access coverage for agents  (`Get-HawkTenantAgentConditionalAccess`)
**Forensic value:** Hardening posture — which agents are/aren't covered by a blocking CA baseline
(e.g. block on high agent risk).
**Source (Graph):** `GET /identity/conditionalAccess/policies`; identify policies targeting agent
identities / agent risk; cross-reference the inventory.
**Flag:** agents not covered by any blocking baseline; no agent-risk CA policy present at all.
**Output:** `AgentConditionalAccess.csv/.json`, `_Investigate_*`.

## P9 — Stale / inactive & disabled agent report  (`Get-HawkTenantStaleAgent`)
**Forensic value:** Attack-surface reduction — enabled agents with no recent sign-ins are dormant
risk; disabled-but-present agents linger.
**Source (Graph):** combine the inventory with **P2** sign-in data (last sign-in per agent).
**Depends on:** P2.
**Flag:** enabled agent with no sign-in in N days (default 30 / 90); disabled agent still present.
**Output:** `StaleAgents.csv/.json`, `_Investigate_StaleAgents.*`.

## P10 — Tag agents in existing collectors
**Forensic value:** Integration — make the broader tenant collectors agent-aware. Low effort.
**Where:** in `Get-HawkTenantConsentGrant.ps1` and `Get-HawkTenantAppAndSPNCredentialDetail.ps1`,
cross-reference the inventory and add an `IsAgentIdentity` column to the output.

---

### Out of scope here (needs the UAL or extra infrastructure)
- Copilot/agent **interaction content** (prompts, accessed resources, jailbreak/XPIA) — UAL
  (`Get-HawkTenantAIInteraction` / `Get-HawkUserAIInteraction`, already on this branch) or Purview
  DSPM-for-AI. Not available while the UAL is off.
- **Microsoft Graph Activity Logs** (per-request API calls made by agents) — not a real-time cmdlet;
  requires diagnostic-settings streaming to Log Analytics / Event Hub / Storage. Advanced,
  infra-dependent follow-up.
