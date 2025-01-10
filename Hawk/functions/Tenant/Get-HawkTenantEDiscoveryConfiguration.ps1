Function Get-HawkTenantEDiscoveryConfiguration {
    <#
    .SYNOPSIS
        Gets complete eDiscovery configuration data across built-in and custom role assignments.

    .DESCRIPTION
        Retrieves comprehensive eDiscovery permissions data from two distinct sources in Exchange Online:

        1. Built-in Exchange Online Role Groups:
        - Standard eDiscovery roles like "Discovery Management"
        - Pre-configured with specific eDiscovery capabilities
        - Managed through Exchange admin center
        - Typically used for organization-wide eDiscovery access
        - Includes mailbox search and hold capabilities
        - Part of Microsoft's default security model

        2. Custom Management Role Entries:
        - User-created roles with eDiscovery permissions
        - Can be tailored for specific business needs
        - May include subset of eDiscovery capabilities
        - Often created for specialized teams or scenarios
        - Requires careful monitoring for security
        - May grant permissions through role assignments
        - Can include cmdlets like:
            * New-MailboxSearch
            * Search-Mailbox

        The function captures all properties and relationships to provide a complete
        view of who has eDiscovery access and how those permissions were granted.
        This helps security teams audit and manage eDiscovery permissions effectively.

    .OUTPUTS
        File: EDiscoveryRoles.csv/.json
        Path: \Tenant
        Description: Complete data about standard Exchange Online eDiscovery role groups
        Contains: Role names, members, assigned permissions, creation dates, and all
                associated properties for built-in eDiscovery roles

        File: CustomEDiscoveryRoles.csv/.json
        Path: \Tenant
        Description: Complete data about custom roles with eDiscovery permissions
        Contains: Custom role definitions, assignments, scope, creation dates, and all
                configurable properties for user-created roles with eDiscovery access

    .EXAMPLE
        Get-HawkTenantEDiscoveryConfiguration

        Returns complete, unfiltered eDiscovery permission data showing both built-in
        role groups and custom role assignments that grant eDiscovery access.

    .NOTES
        Built-in roles provide consistent, pre-configured access while custom roles
        offer flexibility but require more oversight. Regular review of both types
        is recommended for security compliance.
    #>
    [CmdletBinding()]
    param()

    #TO DO: UPDATE THIS FUNCTION TO FIND E-Discovery roles created via the graph API

    BEGIN {
        if ([string]::IsNullOrEmpty($Hawk.FilePath)) {
            Initialize-HawkGlobalObject
        }

        Test-EXOConnection
        Send-AIEvent -Event "CmdRun"

        Out-LogFile "Gathering complete E-Discovery Configuration" -action

        # Create tenant folder if needed
        $TenantPath = Join-Path -Path $Hawk.FilePath -ChildPath "Tenant"
        if (-not (Test-Path -Path $TenantPath)) {
            New-Item -Path $TenantPath -ItemType Directory -Force | Out-Null
        }

        # Null out role arrays
        [array]$Roles = $null
        [array]$RoleAssignements = $null
    }

    PROCESS {
        try {
            #region Exchange Online Role Groups - Full Data
            Out-LogFile "Gathering all Exchange Online role entries with eDiscovery cmdlets" -Action
            
            # Find any roles that have eDiscovery cmdlets
            $EDiscoveryCmdlets = "New-MailboxSearch", "Search-Mailbox"
            
            foreach ($cmdlet in $EDiscoveryCmdlets) {
                [array]$Roles = $Roles + (Get-ManagementRoleEntry ("*\" + $cmdlet))
            }

            # Select just the unique entries based on role name
            if ($Roles) {
                $UniqueRoles = $Roles | Sort-Object -Property Role -Unique

                Out-LogFile ("Found " + $UniqueRoles.Count + " Roles with E-Discovery Rights") -Information
                
                # Save complete role data
                $UniqueRoles | ConvertTo-Json -Depth 100 | 
                    Out-File (Join-Path -Path $TenantPath -ChildPath "EDiscoveryRoles.json")
                $UniqueRoles | Export-Csv -Path (Join-Path -Path $TenantPath -ChildPath "EDiscoveryRoles.csv") -NoTypeInformation

                # Get everyone who is assigned one of these roles
                foreach ($Role in $UniqueRoles) {
                    [array]$RoleAssignements = $RoleAssignements + (Get-ManagementRoleAssignment -Role $Role.Role -Delegating $false)
                }

                if ($RoleAssignements) {
                    Out-LogFile ("Found " + $RoleAssignements.Count + " Role Assignments for these Roles") -Information
                    
                    # Save complete assignment data
                    $RoleAssignements | ConvertTo-Json -Depth 100 | 
                        Out-File (Join-Path -Path $TenantPath -ChildPath "CustomEDiscoveryRoles.json")
                    $RoleAssignements | Export-Csv -Path (Join-Path -Path $TenantPath -ChildPath "CustomEDiscoveryRoles.csv") -NoTypeInformation
                }
                else {
                    Out-LogFile "Get-HawkTenantEDiscoveryConfiguration completed successfully" -Information
                    Out-LogFile "No role assignments found" -action
                }
            }
            else {
                Out-LogFile "Get-HawkTenantEDiscoveryConfiguration completed successfully" -Information
                Out-LogFile "No roles with eDiscovery cmdlets found" -action
            }

            #endregion
        }
        catch {
            Out-LogFile "Error gathering eDiscovery configuration: $($_.Exception.Message)" -isError
            Write-Error -ErrorRecord $_ -ErrorAction Continue
        }
    }

    END {
        Out-LogFile "Completed gathering eDiscovery configuration" -Information
    }
}