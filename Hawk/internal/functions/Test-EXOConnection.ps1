<#
.SYNOPSIS
    Test if we are connected to Exchange Online and connect if not
.DESCRIPTION
    Test if we are connected to Exchange Online and connect if not
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
Function Test-EXOConnection {
    # Check our token cache and if it will expire in less than 15 min renew the session
    $Expires = (Get-TokenCache | Where-Object { $_.resource -like "*outlook.office365.com*" }).ExpiresOn

    # if Expires is null we want to just move on
    if ($null -eq $Expires) { }
    else {
        # If it is not null then we need to see if it is expiring soon
        if (($Expires - ((get-date).AddMinutes(15)) -le 0)) {
            Out-LogFile "Token Near Expiry - rebuilding EXO connection"
            Connect-EXO
        }
    }

    # In all cases make sure we are "connected" to EXO
    try {
        $null = Get-OrganizationConfig -erroraction stop

    }
    catch [System.Management.Automation.CommandNotFoundException] {
        # Connect to EXO if we couldn't find the command
        Out-LogFile "Not Connected to Exchange Online"
        Out-LogFile "Connecting to EXO using CloudConnect Module"
        Connect-EXO
    }
}