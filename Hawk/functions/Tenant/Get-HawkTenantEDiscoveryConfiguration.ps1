Function Get-HawkTenantEDiscoveryConfiguration {
    <#
    .SYNOPSIS
        Gets eDiscovery permissions across Exchange Online and Microsoft 365 platforms using multiple detection methods.
    
    .DESCRIPTION
        Retrieves eDiscovery permissions using three complementary methods to ensure complete coverage:

        1. Exchange Online Role Groups:
           - Finds built-in Exchange Online eDiscovery roles like "Discovery Management"
           - Detects roles with direct mailbox search and hold capabilities
           - Limited to Exchange Online mailbox operations
           - Managed through Exchange admin center/PowerShell

        2. Graph API eDiscovery Roles:
           - Detects Microsoft 365 eDiscovery Manager/Administrator roles
           - These roles have broader access across all Microsoft 365 services
           - Can manage full eDiscovery cases and content
           - Can search Exchange, SharePoint, and OneDrive content
           - Managed through Microsoft 365 admin center

        3. Custom Roles with eDiscovery Permissions:
           - Finds custom-created roles with eDiscovery cmdlet access
           - Includes roles with New-MailboxSearch and Search-Mailbox capabilities
           - Limited to Exchange Online operations
           - Often created for specific organizational needs

        The function maintains original data structures in JSON format while providing
        a unified view in CSV format for analysis.

    .OUTPUTS
        Original Data (JSON):
        File: ExchangeRoleGroups.json
        Description: Raw Exchange Online role group data

        File: GraphAPIEDiscoveryRoles.json
        Description: Raw Microsoft 365 eDiscovery role data

        File: CustomEDiscoveryRoles.json
        Description: Raw custom role data with eDiscovery permissions

        Combined Data:
        File: AllEDiscoveryRoles.csv
        Description: Unified, flattened view of all eDiscovery roles and assignments

    .EXAMPLE
        Get-HawkTenantEDiscoveryConfiguration

        Retrieves and analyzes all eDiscovery permissions across platforms, maintaining
        original data structures while providing a unified analysis view.

    .NOTES
        Each detection method finds different types of permissions:
        - Exchange roles focus on mailbox-level operations
        - Graph API roles provide broader Microsoft 365 access
        - Custom roles may have varying levels of access based on assigned cmdlets
    #>
    [CmdletBinding()]
    param()

    BEGIN {
        if ([string]::IsNullOrEmpty($Hawk.FilePath)) {
            Initialize-HawkGlobalObject
        }

        Test-GraphConnection
        Test-EXOConnection
        Send-AIEvent -Event "CmdRun"

        Out-LogFile "Starting eDiscovery permission analysis" -action

        # Create tenant folder if needed
        $TenantPath = Join-Path -Path $Hawk.FilePath -ChildPath "Tenant"
        if (-not (Test-Path -Path $TenantPath)) {
            New-Item -Path $TenantPath -ItemType Directory -Force | Out-Null
        }

        # Initialize array for combined output
        $allRoles = @()
    }

    PROCESS {
        try {
            #region Exchange Online Role Groups
            Out-LogFile "Checking Exchange Online role groups" -action

            try {
                $exchangeGroups = Get-RoleGroup | Where-Object { 
                    $_.Name -like "*Discovery*" -or 
                    $_.Roles -like "*Discovery*" 
                }

                if ($exchangeGroups) {
                    # Save original JSON structure
                    $exchangeGroups | ConvertTo-Json -Depth 10 | 
                        Out-File (Join-Path -Path $TenantPath -ChildPath "ExchangeRoleGroups.json")

                    # Flatten for combined output
                    foreach ($group in $exchangeGroups) {
                        $allRoles += [PSCustomObject]@{
                            SourceType = "Exchange"
                            RoleName = $group.Name
                            DisplayName = $group.DisplayName
                            Description = $group.Description
                            Members = $group.Members -join ";"
                            Roles = $group.Roles -join ";"
                            RoleAssignments = $group.RoleAssignments -join ";"
                            ManagedBy = $group.ManagedBy -join ";"
                            WhenCreatedUTC = $group.WhenCreatedUTC
                            WhenChangedUTC = $group.WhenChangedUTC
                            Type = $group.RoleGroupType
                        }
                    }

                    Out-LogFile "Found $($exchangeGroups.Count) Exchange role groups" -Information
                }
                else {
                    Out-LogFile "No Exchange eDiscovery role groups found" -Information
                }
            }
            catch {
                Out-LogFile "Error checking Exchange role groups: $($_.Exception.Message)" -isError
            }
            #endregion

            #region Graph API Roles
            Out-LogFile "Checking Graph API eDiscovery roles" -action

            try {
                $graphRoles = @(
                    @{ 
                        Id = "c430b396-e693-46cc-96f3-db01bf8bb62a"
                        Name = "eDiscovery Manager"
                        Description = "Can perform searches and manage eDiscovery cases across Microsoft 365"
                    },
                    @{ 
                        Id = "8101c9e6-6e5c-4d98-a460-f1c27ee29a99"
                        Name = "eDiscovery Administrator"
                        Description = "Can manage all eDiscovery cases and delegate case access"
                    }
                )

                $graphResults = @()

                foreach ($role in $graphRoles) {
                    try {
                        $roleInfo = Get-MgDirectoryRole -DirectoryRoleId $role.Id -ErrorAction Stop
                        if ($roleInfo) {
                            $members = Get-MgDirectoryRoleMember -DirectoryRoleId $role.Id
                            
                            $graphResults += [PSCustomObject]@{
                                Role = $roleInfo
                                Members = $members
                                Description = $role.Description
                            }

                            # Add to combined output
                            $allRoles += [PSCustomObject]@{
                                SourceType = "GraphAPI"
                                RoleName = $role.Name
                                DisplayName = $roleInfo.DisplayName
                                Description = $role.Description
                                Members = ($members | ForEach-Object { 
                                    $_.AdditionalProperties.userPrincipalName 
                                }) -join ";"
                                Roles = $role.Name
                                RoleAssignments = $null
                                ManagedBy = $null
                                WhenCreatedUTC = $null  # Graph API doesn't provide this
                                WhenChangedUTC = $null
                                Type = "Microsoft 365"
                            }
                        }
                    }
                    catch {
                        if ($_.Exception.Message -notlike "*Resource*not found*") {
                            Out-LogFile "Error checking Graph role $($role.Name): $($_.Exception.Message)" -isError
                        }
                    }
                }

                if ($graphResults) {
                    # Save original JSON structure
                    $graphResults | ConvertTo-Json -Depth 10 | 
                        Out-File (Join-Path -Path $TenantPath -ChildPath "GraphAPIEDiscoveryRoles.json")

                    Out-LogFile "Found $($graphResults.Count) Graph API roles" -Information
                }
                else {
                    Out-LogFile "No Graph API eDiscovery roles found" -Information
                }
            }
            catch {
                Out-LogFile "Error checking Graph API roles: $($_.Exception.Message)" -isError
            }
            #endregion

            #region Custom Roles
            Out-LogFile "Checking custom roles with eDiscovery permissions" -action

            try {
                $eDiscoveryCmdlets = @("New-MailboxSearch", "Search-Mailbox")
                $customRoles = @()
                $customResults = @()

                foreach ($cmdlet in $eDiscoveryCmdlets) {
                    $roleEntries = Get-ManagementRoleEntry ("*\" + $cmdlet) -ErrorAction Stop
                    if ($roleEntries) {
                        $customRoles += $roleEntries | 
                            Where-Object { $_.Role -notlike "*Discovery*" } | 
                            Select-Object -Property Role -Unique
                    }
                }

                if ($customRoles) {
                    foreach ($role in $customRoles) {
                        $assignments = Get-ManagementRoleAssignment -Role $role.Role -Delegating $false
                        
                        $roleInfo = [PSCustomObject]@{
                            Role = $role.Role
                            Assignments = $assignments
                        }
                        $customResults += $roleInfo

                        # Add to combined output
                        $allRoles += [PSCustomObject]@{
                            SourceType = "Custom"
                            RoleName = $role.Role
                            DisplayName = $null
                            Description = $null
                            Members = ($assignments | ForEach-Object { $_.RoleAssignee }) -join ";"
                            Roles = $role.Role
                            RoleAssignments = ($assignments | ForEach-Object { $_.Name }) -join ";"
                            ManagedBy = $null
                            WhenCreatedUTC = ($assignments | Select-Object -First 1).WhenCreatedUTC
                            WhenChangedUTC = ($assignments | Select-Object -First 1).WhenChangedUTC
                            Type = "Custom"
                        }
                    }

                    # Save original JSON structure
                    $customResults | ConvertTo-Json -Depth 10 | 
                        Out-File (Join-Path -Path $TenantPath -ChildPath "CustomEDiscoveryRoles.json")

                    Out-LogFile "Found $($customRoles.Count) custom roles" -Information
                }
                else {
                    Out-LogFile "No custom roles with eDiscovery permissions found" -Information
                }
            }
            catch {
                Out-LogFile "Error checking custom roles: $($_.Exception.Message)" -isError
            }
            #endregion

            # Export combined CSV
            if ($allRoles.Count -gt 0) {
                $allRoles | Export-Csv -Path (Join-Path -Path $TenantPath -ChildPath "AllEDiscoveryRoles.csv") -NoTypeInformation
                Out-LogFile "Found total of $($allRoles.Count) eDiscovery roles across all platforms" -notice
            }
            else {
                Out-LogFile "No eDiscovery roles found on any platform" -notice
            }
        }
        catch {
            Out-LogFile "Error in eDiscovery configuration analysis: $($_.Exception.Message)" -isError
            Write-Error -ErrorRecord $_ -ErrorAction Continue
        }
    }

    END {
        Out-LogFile "Completed eDiscovery permission analysis" -action
    }
}