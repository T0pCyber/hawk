<#
.SYNOPSIS
    Test if we are connected to Graph and connect if not
.DESCRIPTION
    Test if we are connected to Graph and connect if not
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    https://learn.microsoft.com/en-us/powershell/microsoftgraph/get-started?view=graph-powershell-1.0

#>
Function Test-GraphConnection {
    # Get tenant details to test that Connect-MgGraph has been called
    try { $null = Get-MgOrganization -ErrorAction stop }
    catch {
        # Write to the screen if we don't have a log file path yet
        if ([string]::IsNullOrEmpty($Hawk.Logfile)) {
            Write-Output "Connecting to MGGraph using MGGraph Module"
        }
        # Otherwise output to the log file
        else {
            Out-LogFile "Connecting to MGGraph using MGGraph Module"
        }
        Connect-MGGraph
    }
}