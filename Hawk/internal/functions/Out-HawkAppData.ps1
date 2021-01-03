<#
.SYNOPSIS
    Output hawk appdata to a file
.DESCRIPTION
    Output hawk appdata to a file
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
Function Out-HawkAppData {
    $HawkAppdataPath = join-path $env:LOCALAPPDATA "Hawk\Hawk.json"
    $HawkAppdataFolder = join-path $env:LOCALAPPDATA "Hawk"

    # test if the folder exists
    if (test-path $HawkAppdataFolder) { }
    # if it doesn't we need to create it
    else {
        $null = New-Item -ItemType Directory -Path $HawkAppdataFolder
    }

    Out-LogFile ("Recording HawkAppData to file " + $HawkAppdataPath)
    $global:HawkAppData | ConvertTo-Json | Out-File -FilePath $HawkAppdataPath -Force
}