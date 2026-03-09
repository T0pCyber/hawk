<#
.SYNOPSIS
    Test if we are connected to Exchange Online and connect if not
.DESCRIPTION
    Test if we are connected to Exchange Online and connect if not.
    Catches all connection failures including expired sessions and
    MSAL authentication errors, with a single retry before failing.
.EXAMPLE
    PS C:\> Test-EXOConnection
    Tests the current Exchange Online connection and reconnects if needed.
.OUTPUTS
    None. Throws a terminating error if connection cannot be established.
.NOTES
    General notes
#>
Function Test-EXOConnection {
    # In all cases make sure we are "connected" to EXO
    try {
        $null = Get-OrganizationConfig -ErrorAction Stop
    }
    catch {
        # Connect to EXO if not connected or session is stale/expired
        Out-LogFile "Not Connected to Exchange Online" -Information
        Out-LogFile "Connecting to EXO using Exchange Online Module" -Action

        try {
            Connect-ExchangeOnline -ErrorAction Stop
        }
        catch {
            Out-LogFile "Initial EXO connection attempt failed: $($_.Exception.Message)" -Information
            Out-LogFile "Retrying EXO connection..." -Action
            try {
                Connect-ExchangeOnline -ErrorAction Stop
            }
            catch {
                $errorMessage = @(
                    "Unable to connect to Exchange Online: $($_.Exception.Message)"
                    "Please try running 'Connect-ExchangeOnline' manually before running Hawk."
                )
                Stop-PSFFunction -Message ($errorMessage -join "`n") -EnableException $true
            }
        }
    }
}