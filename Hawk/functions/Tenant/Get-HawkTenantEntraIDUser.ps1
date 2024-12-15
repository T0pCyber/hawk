﻿Function Get-HawkTenantEntraIDUser {
    <#
    .SYNOPSIS
        This function will export all the Entra ID users (formerly Azure AD users).
    .DESCRIPTION
        This function exports all the Entra ID users to a .csv file, focusing on properties
        relevant for digital forensics and incident response. Properties include user identity,
        account status, and account dates.

        Note: SignInActivity requires additional AuditLog.Read.All permission and is currently commented out.
    .EXAMPLE
        PS C:\>Get-HawkTenantEntraIDUser
        Exports all Entra ID users with DFIR-relevant properties to .csv and .json files.
    .OUTPUTS
        EntraIDUsers.csv, EntraIDUsers.json
    .LINK
        https://learn.microsoft.com/en-us/graph/api/user-list?view=graph-rest-1.0&tabs=powershell
    .NOTES
        Updated to use Microsoft Graph SDK instead of AzureAD module.
        Properties selected for DFIR relevance.
    #>
    BEGIN {
        # Initialize the Hawk environment if not already done
        if ([string]::IsNullOrEmpty($Hawk.FilePath)) {
            Initialize-HawkGlobalObject
        }
        Out-LogFile "Gathering Entra ID Users"

        # Ensure we have a valid Graph connection
        Test-GraphConnection
    }
    PROCESS {
        # Get all users with specific properties needed for DFIR
        # -Property parameter optimizes API call to only retrieve needed fields
        $users = Get-MgUser -All -Property UserPrincipalName,    # Primary user identifier
            DisplayName,                                         # User's display name
            Id,                                                 # Unique object ID
            AccountEnabled,                                     # Account status (active/disabled)
            CreatedDateTime,                                    # Account creation timestamp
            DeletedDateTime,                                    # Account deletion timestamp (if applicable)
            LastPasswordChangeDateTime,                         # Last password modification
            Mail |                                             # Primary email address
            Select-Object UserPrincipalName,
                DisplayName,
                Id,
                AccountEnabled,
                CreatedDateTime,
                DeletedDateTime,
                LastPasswordChangeDateTime,
                Mail

        # Only process if users were found
        if ($users) {
            # Sort by UPN and export to both CSV and JSON formats
            $users | Sort-Object -Property UserPrincipalName |
                Out-MultipleFileType -FilePrefix "EntraIDUsers" -csv -json
        }
        else {
            Out-LogFile "No users found"
        }
    }
    END {
        Out-Logfile "Completed exporting Entra ID users"
    }
 }