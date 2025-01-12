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
    try {
        $null = Get-MgOrganization -ErrorAction Stop
    }
    catch {
        # Fallback if $Hawk is not initialized
        $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss")

        if ($null -eq $Hawk) {
            # Use standardized timestamp format when Hawk isn't initialized
            Write-Output "[$timestamp UTC] - [ACTION] - Connecting to Microsoft Graph API"
        }
        else {
            # $Hawk exists, so we can safely use Out-LogFile 
            Write-Output "[$timestamp UTC] - [ACTION] - Connecting to Microsoft Graph API"
        }

        Connect-MGGraph
    }
}
