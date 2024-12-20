Function Get-HawkTenantImpersonationAccess {
    <#
    .SYNOPSIS
        Checks for Exchange impersonation roles and their assignments in the tenant.

    .DESCRIPTION
        This function examines Exchange impersonation configuration by:
        1. Finding all roles containing the Impersonate-ExchangeUser cmdlet
        2. Identifying all users and groups assigned to those roles
        
        Non-default configurations (more than one role or assignment) are flagged
        for investigation as they may indicate excessive impersonation rights.

    .OUTPUTS
        File: Impersonation_Roles.csv/.json/.xml
        Path: \Tenant
        Description: List of roles with impersonation rights (default config)

        File: _Investigate_Impersonation_Roles.csv/.json/.xml
        Path: \Tenant
        Description: List of roles with impersonation rights (non-default config)

        File: Impersonation_Rights.csv/.json/.xml
        Path: \Tenant
        Description: List of users/groups with impersonation rights (default config)

        File: _Investigate_Impersonation_Rights.csv/.json/.xml
        Path: \Tenant
        Description: List of users/groups with impersonation rights (non-default config)

    .EXAMPLE
        Get-HawkTenantImpersonationAccess

        Checks impersonation roles and assignments, flagging any non-default configurations.
    #>
    [CmdletBinding()]
    param()

    Test-EXOConnection
    Send-AIEvent -Event "CmdRun"

    Out-LogFile "Analyzing Exchange impersonation access" -Action

    # Create tenant folder if it doesn't exist
    $TenantPath = Join-Path -Path $Hawk.FilePath -ChildPath "Tenant"
    if (-not (Test-Path -Path $TenantPath)) {
        New-Item -Path $TenantPath -ItemType Directory -Force | Out-Null
    }

    try {
        # Check for impersonation roles
        Out-LogFile "Searching for roles with Impersonate-ExchangeUser rights" -action
        [array]$TenantImpersonatingRoles = Get-ManagementRoleEntry "*\Impersonate-ExchangeUser" -ErrorAction Stop

        switch ($TenantImpersonatingRoles.Count) {
            0 { 
                Out-LogFile "No impersonation roles found - This is unusual and should be investigated" -Notice
                return
            }
            1 { 
                Out-LogFile "Found default number of impersonation roles (1)"
                $TenantImpersonatingRoles | Out-MultipleFileType -FilePrefix "Impersonation_Roles" -csv -json -xml
            }
            default {
                Out-LogFile "Found $($TenantImpersonatingRoles.Count) impersonation roles - Default is 1" -Notice
                Out-LogFile "Additional impersonation roles may indicate overly broad permissions" -Notice
                $TenantImpersonatingRoles | Out-MultipleFileType -FilePrefix "_Investigate_Impersonation_Roles" -csv -json -xml -Notice
                
                # Log details about each role for investigation
                foreach ($role in $TenantImpersonatingRoles) {
                    Out-LogFile "Found impersonation role: $($role.Role)" -Notice
                }
            }
        }

        # Check role assignments 
        Out-LogFile "Checking who has been assigned impersonation roles" -action
        $RoleAssignments = @()
        foreach ($Role in $TenantImpersonatingRoles) {
            try {
                $assignments = Get-ManagementRoleAssignment -Role $Role.Role -GetEffectiveUsers -Delegating:$false -ErrorAction Stop
                if ($assignments) {
                    $RoleAssignments += $assignments
                }
            }
            catch {
                Out-LogFile "Error getting assignments for role $($Role.Role): $($_.Exception.Message)" -Notice
                continue
            }
        }

        switch ($RoleAssignments.Count) {
            0 {
                Out-LogFile "No impersonation role assignments found - This is unusual and should be investigated" -Notice
            }
            1 {
                Out-LogFile "Found default number of impersonation assignments (1)"
                $RoleAssignments | Out-MultipleFileType -FilePrefix "Impersonation_Rights" -csv -json -xml

                # Log who has the default assignment
                Out-LogFile "Default impersonation assigned to: $($RoleAssignments[0].RoleAssignee)"
            }
            default {
                Out-LogFile "Found $($RoleAssignments.Count) impersonation assignments - Default is 1" -Notice
                Out-LogFile "Multiple assignments may indicate excessive impersonation rights" -Notice
                $RoleAssignments | Out-MultipleFileType -FilePrefix "_Investigate_Impersonation_Rights" -csv -json -xml -Notice

                # Log details about each assignment for investigation
                foreach ($assignment in $RoleAssignments) {
                    Out-LogFile "Found assignment: Role: $($assignment.Role) assigned to: $($assignment.RoleAssignee)" -Notice
                }
            }
        }

        # Provide summary if non-default configuration found
        if ($TenantImpersonatingRoles.Count -gt 1 -or $RoleAssignments.Count -gt 1) {
            Out-LogFile "INVESTIGATION REQUIRED: Non-default impersonation configuration detected" -Notice
            if ($TenantImpersonatingRoles.Count -gt 1) {
                Out-LogFile "- Multiple impersonation roles found ($($TenantImpersonatingRoles.Count))" -Notice
            }
            if ($RoleAssignments.Count -gt 1) {
                Out-LogFile "- Multiple impersonation assignments found ($($RoleAssignments.Count))" -Notice
            }
            Out-LogFile "Excessive impersonation rights could allow unauthorized mailbox access" -Notice
        }
        elseif ($TenantImpersonatingRoles.Count -eq 0 -or $RoleAssignments.Count -eq 0) {
            Out-LogFile "WARNING: Missing expected impersonation configuration" -Notice
            Out-LogFile "Default configuration should have 1 role and 1 assignment" -Notice
        }
    }
    catch {
        Out-LogFile "Error analyzing impersonation access: $($_.Exception.Message)" -Notice
        Write-Error -ErrorRecord $_ -ErrorAction Continue
    }
}