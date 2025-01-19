Function Clear-HawkEnvironment {
    <#
    .SYNOPSIS
        Cleans up Hawk global variables and environment state.
    
    .DESCRIPTION
        Removes Hawk-specific global variables and cleans up the PowerShell environment
        after Hawk operations complete. This prevents state persistence between runs
        and ensures a clean environment for subsequent executions.
    
    .EXAMPLE
        Clear-HawkEnvironment
        
        Cleans up all Hawk global variables and environment state.
    #>
    [CmdletBinding()]
    param()
    
    try {
        # List of known Hawk global variables to remove
        $hawkGlobals = @(
            'Hawk',
            'HawkAppData',
            'MSFTIPList',
            'IPLocationCache'
        )

        # Remove each Hawk global variable if it exists
        foreach ($varName in $hawkGlobals) {
            if (Get-Variable -Name $varName -ErrorAction SilentlyContinue) {
                Remove-Variable -Name $varName -Scope Global -Force -ErrorAction SilentlyContinue
                Write-Verbose "Removed global variable: $varName"
            }
        }

        # Clear the error variable
        $Error.Clear()

        Write-Verbose "Hawk environment cleanup completed successfully"
    }
    catch {
        Write-Warning "Error during Hawk environment cleanup: $_"
        # Don't throw here - we don't want cleanup failures to affect the user
    }
}