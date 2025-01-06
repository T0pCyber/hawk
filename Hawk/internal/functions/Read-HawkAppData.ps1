<#
.SYNOPSIS
    Read in hawk app data if it is there
.DESCRIPTION
    Read in hawk app data if it is there
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
Function Read-HawkAppData {
    $HawkAppdataPath = join-path $env:LOCALAPPDATA "Hawk\Hawk.json"

    # check to see if our xml file is there
    if (test-path $HawkAppdataPath) {
        Out-LogFile ("Reading file " + $HawkAppdataPath) -Action
        $global:HawkAppData = ConvertFrom-Json -InputObject ([string](Get-Content $HawkAppdataPath))

        # Harmless reference to satisfy PSSA requirement
        if ($null -eq $global:HawkAppData) { }

    }
    # if we don't have an xml file then do nothing
    else {
        Out-LogFile ("No HawkAppData File found " + $HawkAppdataPath) -Information
    }
}