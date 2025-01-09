Function Get-HawkTenantEntraIDAdmin {
    <#
    .SYNOPSIS
        Tenant Microsoft Entra ID Administrator export using Microsoft Graph.
    .DESCRIPTION
        Tenant Microsoft Entra ID Administrator export. Reviewing administrator access is key to knowing who can make changes
        to the tenant and conduct other administrative actions to users and applications.
    .EXAMPLE
        Get-HawkTenantEntraIDAdmin
        Gets all Entra ID Admins
    .OUTPUTS
        EntraIDAdministrators.csv
        EntraIDAdministrators.json
    .LINK
        https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.identity.directorymanagement/get-mgdirectoryrole
    .NOTES
        Requires Microsoft.Graph.Identity.DirectoryManagement module
    #>
        [CmdletBinding()]
        param()

        BEGIN {
            # Initializing Hawk Object if not present
            if ([string]::IsNullOrEmpty($Hawk.FilePath)) {
                Initialize-HawkGlobalObject
            }
            Out-LogFile "Gathering Microsoft Entra ID Administrators" -Action

            # Verify Graph API connection
            Test-GraphConnection
            Send-AIEvent -Event "CmdRun"
        }

        PROCESS {
            try {
                # Retrieve all directory roles from Microsoft Graph
                $directoryRoles = Get-MgDirectoryRole -ErrorAction Stop
                Out-LogFile "Retrieved $(($directoryRoles | Measure-Object).Count) directory roles" -Information

                # Process each role and its members
                $roles = foreach ($role in $directoryRoles) {
                    # Get all members assigned to current role
                    $members = Get-MgDirectoryRoleMember -DirectoryRoleId $role.Id -ErrorAction Stop

                    # Handle roles with no members
                    if (-not $members) {
                        [PSCustomObject]@{
                            AdminGroupName = $role.DisplayName
                            Members = "No Members"
                            MemberType = "None"  # Added member type for better analysis
                            ObjectId = $null
                        }
                    }
                    else {
                        # Process each member of the role
                        foreach ($member in $members) {
                            # Check if member is a user
                            if ($member.AdditionalProperties.'@odata.type' -eq "#microsoft.graph.user") {
                                [PSCustomObject]@{
                                    AdminGroupName = $role.DisplayName
                                    Members = $member.AdditionalProperties.userPrincipalName
                                    MemberType = "User"
                                    ObjectId = $member.Id
                                }
                            }
                            else {
                                # Handle groups and service principals
                                [PSCustomObject]@{
                                    AdminGroupName = $role.DisplayName
                                    Members = $member.AdditionalProperties.displayName
                                    MemberType = ($member.AdditionalProperties.'@odata.type' -replace '#microsoft.graph.', '')
                                    ObjectId = $member.Id
                                }
                            }
                        }
                    }
                }

                # Export results if any roles were found
                if ($roles) {
                    $roles | Out-MultipleFileType -FilePrefix "EntraIDAdministrators" -csv -json
                    Out-LogFile "Successfully exported Microsoft Entra ID Administrators data" -Information
                }
                else {
                    Out-LogFile "No administrator roles found or accessible" -Information
                }
            }
            catch {
                # Handle and log any errors during execution
                Out-LogFile "Error retrieving Microsoft Entra ID Administrators: $($_.Exception.Message)" -isError
                Write-Error -ErrorRecord $_ -ErrorAction Continue
            }
        }

        END {
            Out-LogFile "Completed exporting Microsoft Entra ID Admins" -Information
        }
    }