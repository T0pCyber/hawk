Function Test-OperationEnabled {
    <#
    .SYNOPSIS
        Tests if a specified audit operation is enabled for a given user.

    .DESCRIPTION
        An internal helper function that verifies whether a specific audit operation 
        is enabled in a user's mailbox auditing configuration. This function queries
        the mailbox settings using Get-Mailbox and checks the AuditOwner property
        for the specified operation.

    .PARAMETER User
        The UserPrincipalName of the user to check auditing configuration for.
        
    .PARAMETER Operation
        The specific audit operation to check for (e.g., 'SearchQueryInitiated').

    .EXAMPLE
        $result = Test-OperationEnabled -User "user@contoso.com" -Operation "SearchQueryInitiated"
        
        Checks if the SearchQueryInitiated operation is enabled for user@contoso.com's mailbox.
        Returns True if enabled, False if not enabled.

    .EXAMPLE
        if (Test-OperationEnabled -User $userUpn -Operation 'MailItemsAccessed') {
            # Proceed with mail items access audit
        }

        Shows how to use the function in a conditional check before performing
        an audit operation that requires specific permissions.

    .OUTPUTS
        System.Boolean
        Returns True if the operation is enabled for the user, False otherwise.

    .NOTES
        Internal Function
        Author: Jonathan Butler
        Requirements: Exchange Online PowerShell session with appropriate permissions
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory=$true)]
        [string]$User,
        [Parameter(Mandatory=$true)]
        [string]$Operation
    )

    # Verify the provided User has the specified Operation enabled
    $TestResult = Get-Mailbox -Identity $User | Where-Object -Property AuditOwner -eq $Operation

    if ($null -eq $TestResult) {
        return $false
    } else {
        return $true
    }
}