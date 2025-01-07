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
        if ($null -eq $Hawk) {
            # Replicate Out-LogFile's date/time format and ACTION style
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Write-Output "[$timestamp] - [ACTION] - Connecting to MGGraph using MGGraph Module"
        }
        else {
            # $Hawk exists, so we can safely use Out-LogFile 
            Out-LogFile -String "Connecting to MGGraph using MGGraph Module" -Action
        }

        Connect-MGGraph
    }
}
