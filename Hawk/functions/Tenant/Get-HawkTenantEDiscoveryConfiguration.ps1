Function Get-HawkTenantEDiscoveryConfiguration {
    <#
    .SYNOPSIS
        Gets eDiscovery permissions across both Exchange Online and Microsoft 365 Compliance.
    
    .DESCRIPTION
        Retrieves eDiscovery permissions using three complementary methods:
        1. Exchange Online Role Groups: Checks membership in the Discovery Management role group
        2. Microsoft Graph API: Checks modern eDiscovery Manager/Administrator roles
        3. Management Role Entries: Discovers custom roles with eDiscovery permissions

        This comprehensive approach covers both legacy Exchange eDiscovery and modern 
        Microsoft 365 eDiscovery permissions.

    .OUTPUTS
        File: ModernEDiscoveryRoles.csv/.json
        Path: \Tenant
        Description: Modern eDiscovery Manager/Administrator role assignments via Graph API

        File: ExchangeEDiscoveryRoleGroups.csv/.json
        Path: \Tenant
        Description: Members of Exchange Online Discovery Management role group

        File: CustomEDiscoveryRoles.csv/.json
        Path: \Tenant
        Description: Custom roles with eDiscovery cmdlet permissions

        File: CustomEDiscoveryAssignments.csv/.json
        Path: \Tenant
        Description: All assignments for custom roles with eDiscovery permissions

    .EXAMPLE
        Get-HawkTenantEDiscoveryConfiguration

        Lists all users and groups with eDiscovery permissions across both Exchange Online
        and Microsoft 365 Compliance platforms.

    .NOTES
        This function helps identify potential security risks by:
        - Tracking who has access to both legacy and modern eDiscovery features
        - Monitoring role group and role memberships across platforms
        - Identifying custom roles that may grant unexpected access
        - Flagging potentially risky configurations
    #>
    [CmdletBinding()]
    param()

    BEGIN {
        if ([string]::IsNullOrEmpty($Hawk.FilePath)) {
            Initialize-HawkGlobalObject
        }

        # Verify both Graph and EXO connections
        Test-GraphConnection
        Test-EXOConnection
        Send-AIEvent -Event "CmdRun"

        Out-LogFile "Gathering eDiscovery permissions across Exchange Online and Microsoft 365" -action

        # Create tenant folder if it doesn't exist
        $TenantPath = Join-Path -Path $Hawk.FilePath -ChildPath "Tenant"
        if (-not (Test-Path -Path $TenantPath)) {
            New-Item -Path $TenantPath -ItemType Directory -Force | Out-Null
        }
    }

    PROCESS {
        try {
            #region Check Modern eDiscovery Roles via Graph API
            Out-LogFile "Checking Microsoft 365 eDiscovery roles via Graph API" -action

            try {
                # Get all directory roles to find eDiscovery roles
                $modernEDiscoveryRoles = @(
                    @{
                        Id = "c430b396-e693-46cc-96f3-db01bf8bb62a"
                        Name = "eDiscovery Manager"
                        Description = "Can perform searches and place holds on mailboxes, SharePoint Online sites, and OneDrive for Business locations"
                    },
                    @{
                        Id = "8101c9e6-6e5c-4d98-a460-f1c27ee29a99"
                        Name = "eDiscovery Administrator"
                        Description = "Can perform all eDiscovery actions including managing cases and accessing all case content"
                    }
                )

                $modernRoleMembers = @()
                foreach ($role in $modernEDiscoveryRoles) {
                    try {
                        # Get role by ID first to confirm it exists in tenant
                        $directoryRole = Get-MgDirectoryRole -DirectoryRoleId $role.Id -ErrorAction Stop
                        if ($directoryRole) {
                            $members = Get-MgDirectoryRoleMember -DirectoryRoleId $role.Id -ErrorAction Stop
                            foreach ($member in $members) {
                                $memberType = if ($member.AdditionalProperties.'@odata.type' -eq '#microsoft.graph.user') { 
                                    "User" 
                                } else { 
                                    "Group" 
                                }

                                $modernRoleMembers += [PSCustomObject]@{
                                    RoleId = $role.Id
                                    RoleName = $role.Name
                                    RoleDescription = $role.Description
                                    UserId = $member.Id
                                    UserPrincipalName = $member.AdditionalProperties.userPrincipalName
                                    DisplayName = $member.AdditionalProperties.displayName
                                    AssignmentType = $memberType
                                    Platform = "Microsoft 365"
                                }
                            }
                        }
                    }
                    catch {
                        if ($_.Exception.Message -like "*Resource*not found*") {
                            Out-LogFile "Role $($role.Name) not found in tenant - this is normal if the role isn't used" -Information
                        }
                        else {
                            Out-LogFile "Error checking role $($role.Name): $($_.Exception.Message)" -Notice
                        }
                    }
                }

                if ($modernRoleMembers.Count -gt 0) {
                    Out-LogFile "Found $($modernRoleMembers.Count) users/groups with Microsoft 365 eDiscovery roles"
                    $modernRoleMembers | Out-MultipleFileType -FilePrefix "ModernEDiscoveryRoles" -csv -json
                }
                else {
                    Out-LogFile "No Microsoft 365 eDiscovery role assignments found"
                }
            }
            catch {
                Out-LogFile "Error querying Microsoft 365 eDiscovery roles: $($_.Exception.Message)" -Notice
            }
            #endregion

            #region Check Exchange Online Discovery Management Role Group
            Out-LogFile "Checking Exchange Online Discovery Management role group members" -action

            try {
                $members = Get-RoleGroupMember -Identity "Discovery Management" -ErrorAction Stop
                
                if ($members) {
                    $exchangeRoleMembers = foreach ($member in $members) {
                        [PSCustomObject]@{
                            RoleGroup = "Discovery Management"
                            Name = $member.Name 
                            DisplayName = $member.DisplayName
                            RecipientType = $member.RecipientType
                            WindowsLiveID = $member.WindowsLiveID
                            Platform = "Exchange Online"
                            AssignmentType = 'RoleGroup'
                        }
                    }
                    Out-LogFile "Found $($members.Count) members in Exchange Discovery Management role group"
                    
                    if ($exchangeRoleMembers.Count -gt 0) {
                        $exchangeRoleMembers | Out-MultipleFileType -FilePrefix "ExchangeEDiscoveryRoleGroups" -csv -json
                    }
                }
                else {
                    Out-LogFile "No members found in Exchange Discovery Management role group"
                }
            }
            catch {
                Out-LogFile "Error checking Exchange Discovery Management role group: $($_.Exception.Message)" -Notice
            }
            #endregion

            #region Check Custom Roles with eDiscovery Cmdlets
            Out-LogFile "Checking custom roles with eDiscovery permissions" -action
            
            # Define key eDiscovery cmdlets to check
            $eDiscoveryCmdlets = @(
                "New-MailboxSearch", 
                "Search-Mailbox"
            )
            $customRoles = @()

            foreach ($cmdlet in $eDiscoveryCmdlets) {
                try {
                    Out-LogFile "Checking role entries for cmdlet $cmdlet"
                    $roleEntries = Get-ManagementRoleEntry ("*\" + $cmdlet) -ErrorAction Stop
                    if ($roleEntries) {
                        $customRoles += $roleEntries | Select-Object -Property Role -Unique
                    }
                }
                catch {
                    Out-LogFile "Error checking role entries for cmdlet $cmdlet : $($_.Exception.Message)" -Notice
                }
            }

            if ($customRoles.Count -gt 0) {
                # Filter out standard Discovery Management role
                $customRoles = $customRoles | Where-Object { 
                    $_.Role -notlike "*Discovery*"
                } | Sort-Object Role -Unique

                Out-LogFile "Found $($customRoles.Count) custom roles with eDiscovery permissions" -Notice
                $customRoles | Out-MultipleFileType -FilePrefix "CustomEDiscoveryRoles" -csv -json

                $customRoleAssignments = @()
                foreach ($role in $customRoles) {
                    try {
                        Out-LogFile "Getting assignments for role $($role.Role)"
                        $assignments = Get-ManagementRoleAssignment -Role $role.Role -Delegating $false -ErrorAction Stop
                        foreach ($assignment in $assignments) {
                            $customRoleAssignments += [PSCustomObject]@{
                                RoleName = $role.Role
                                RoleType = "Custom"
                                AssignmentName = $assignment.Name
                                RoleAssigneeType = $assignment.RoleAssigneeType
                                AssigneeDisplayName = $assignment.DisplayName
                                AssignmentEnabled = $assignment.Enabled
                                AssignmentCustom = $assignment.CustomRecipientWriteScope
                                AssigningTimeUTC = $assignment.WhenCreatedUTC
                                Platform = "Exchange Online"
                            }
                        }
                    }
                    catch {
                        Out-LogFile "Error getting assignments for role $($role.Role): $($_.Exception.Message)" -Notice
                    }
                }

                if ($customRoleAssignments.Count -gt 0) {
                    Out-LogFile "Found $($customRoleAssignments.Count) assignments for custom eDiscovery roles" -Notice
                    $customRoleAssignments | Out-MultipleFileType -FilePrefix "CustomEDiscoveryAssignments" -csv -json

                    foreach ($assignment in $customRoleAssignments) {
                        Out-LogFile "Custom Role Assignment found:" -Notice
                        Out-LogFile "  Role: $($assignment.RoleName)" -Notice
                        Out-LogFile "  Assignee: $($assignment.AssigneeDisplayName) ($($assignment.RoleAssigneeType))" -Notice
                        Out-LogFile "  Assigned: $($assignment.AssigningTimeUTC)" -Notice
                        
                        if (-not $assignment.AssignmentEnabled) {
                            Out-LogFile "  Warning: Assignment is disabled" -Notice
                        }
                        if ($assignment.AssignmentCustom) {
                            Out-LogFile "  Warning: Custom recipient scope configured" -Notice
                        }
                    }
                }
            }
            else {
                Out-LogFile "No custom roles with eDiscovery permissions found"
            }
            #endregion

            #region Cross-Platform Summary
            if ($modernRoleMembers.Count -gt 0 -or $exchangeRoleMembers.Count -gt 0 -or $customRoleAssignments.Count -gt 0) {
                Out-LogFile "eDiscovery Permission Summary:" -Notice
                if ($modernRoleMembers.Count -gt 0) {
                    Out-LogFile "  Microsoft 365: $($modernRoleMembers.Count) role assignments" -Notice
                }
                if ($exchangeRoleMembers.Count -gt 0) {
                    Out-LogFile "  Exchange Online: $($exchangeRoleMembers.Count) role group members" -Notice
                }
                if ($customRoleAssignments.Count -gt 0) {
                    Out-LogFile "  Custom Roles: $($customRoleAssignments.Count) role assignments" -Notice
                }
            }
            else {
                Out-LogFile "No eDiscovery permissions found in either platform" -Notice
            }
            #endregion
        }
        catch {
            Out-LogFile "Error gathering eDiscovery permission information: $($_.Exception.Message)" -Notice
            Write-Error -ErrorRecord $_ -ErrorAction Continue
        }
    }

    END {
        Out-LogFile "Completed gathering eDiscovery permissions across platforms"
    }
}