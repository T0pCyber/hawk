<#
.SYNOPSIS
    Test if we are connected to MSOL and connect if we are not
.DESCRIPTION
    Test if we are connected to MSOL and connect if we are not
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
Function Test-MSOLConnection {

    try { $null = Get-MsolCompanyInformation -ErrorAction Stop }
    catch [Microsoft.Online.Administration.Automation.MicrosoftOnlineException] {

        # Write to the screen if we don't have a log file path yet
        if ([string]::IsNullOrEmpty($Hawk.Logfile)) {
            Write-Output "Connecting to MSOLService using MSOnline Module"
        }
        # Otherwise output to the log file
        else {
            Out-LogFile "Connecting to MSOLService using MSOnline Module"
        }

        # Connect to the MSOl Service (This should have been installed with the CloudConnect Module)
        Connect-MsolService

    }
}