<#
.SYNOPSIS
    Test if a user has a specific operation enabled for auditing
.DESCRIPTION
    Test if a user has a specific operation enabled for auditing
.EXAMPLE
    [bool]$result = Test-OperationEnabled -User bsmith@contoso.com -Operation 'SearchQueryInitiated'
.PARAMETER User
    Specific user under investigation
.PARAMETER Operation
    Operation to be verified enabled for auditing
.EXAMPLE
    Test-OperationEnabled -User bsmith@contoso.com -Operation 'SearchQueryInitiated'
    Checks if the SearchQueryInitiated audit operation is enabled for user bsmith@contoso.com. Returns True if enabled, False if disabled.
.OUTPUTS
    System.Boolean
    Output is a boolean result returned to the calling external function
.NOTES
    This function is internal and to be called from another Hawk user-enabled function.  Return value is boolean, and
    it is intended to be used in an if-else check verifying an operation is enabled for auditing under a given user.
#>
Function Test-OperationEnabled {
    
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