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
    # In all cases make sure we are "connected" to EXO
    try {
        $null = Get-OrganizationConfig -erroraction stop
    }
    catch [System.Management.Automation.CommandNotFoundException] {
        # Connect to EXO if we couldn't find the command
        Out-LogFile "Not Connected to Exchange Online"
        Out-LogFile "Connecting to EXO using CloudConnect Module"
        Connect-ExchangeOnline
    }
}