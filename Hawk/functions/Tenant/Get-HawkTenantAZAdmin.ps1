Function Get-HawkTenantAZAdmin {
    <#
    .SYNOPSIS
        Tenant Azure Active Directory Administrator export using Microsoft Graph.
    .DESCRIPTION
        Tenant Azure Active Directory Administrator export. Reviewing administrator access is key to knowing who can make changes
        to the tenant and conduct other administrative actions to users and applications.
    .EXAMPLE
        Get-HawkTenantAZAdmin
        Gets all Azure AD Admins
    .OUTPUTS
        AzureADAdministrators.csv
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
            Out-LogFile "Gathering Azure AD Administrators"

            Test-GraphConnection
            Send-AIEvent -Event "CmdRun"
        }

        PROCESS {
            try {
                # Get all directory roles
                $directoryRoles = Get-MgDirectoryRole -ErrorAction Stop
                Out-LogFile "Retrieved $(($directoryRoles | Measure-Object).Count) directory roles"

                $roles = foreach ($role in $directoryRoles) {
                    # Get members for each role
                    $members = Get-MgDirectoryRoleMember -DirectoryRoleId $role.Id -ErrorAction Stop

                    if (-not $members) {
                        [PSCustomObject]@{
                            AdminGroupName = $role.DisplayName
                            Members = "No Members"
                            MemberType = "None"  # Added member type for better analysis
                            MemberId = $null
                        }
                    }
                    else {
                        foreach ($member in $members) {
                            # Determine member type and get appropriate properties
                            if ($member.AdditionalProperties.'@odata.type' -eq "#microsoft.graph.user") {
                                [PSCustomObject]@{
                                    AdminGroupName = $role.DisplayName
                                    Members = $member.AdditionalProperties.userPrincipalName
                                    MemberType = "User"
                                    MemberId = $member.Id
                                }
                            }
                            else {
                                # Groups or Service Principals
                                [PSCustomObject]@{
                                    AdminGroupName = $role.DisplayName
                                    Members = $member.AdditionalProperties.displayName
                                    MemberType = ($member.AdditionalProperties.'@odata.type' -replace '#microsoft.graph.', '')
                                    MemberId = $member.Id
                                }
                            }
                        }
                    }
                }

                if ($roles) {
                    $roles | Out-MultipleFileType -FilePrefix "AzureADAdministrators" -csv -json
                    Out-LogFile "Successfully exported Azure AD Administrators data"
                }
                else {
                    Out-LogFile "No administrator roles found or accessible" -notice
                }
            }
            catch {
                Out-LogFile "Error retrieving Azure AD Administrators: $($_.Exception.Message)" -notice
                Write-Error -ErrorRecord $_ -ErrorAction Continue
            }
        }

        END {
            Out-LogFile "Completed exporting Azure AD Admins"
        }
    }