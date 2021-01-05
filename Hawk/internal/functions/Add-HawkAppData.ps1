<#
.SYNOPSIS
    Add objects to the hawk app data
.DESCRIPTION
    Add objects to the hawk app data
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
Function Add-HawkAppData {
    param
    (
        [string]$Name,
        [string]$Value
    )

    Out-LogFile ("Adding " + $value + " to " + $Name + " in HawkAppData")

    # Test if our HawkAppData variable exists
    if ([bool](get-variable HawkAppData -ErrorAction SilentlyContinue)) {
        $global:HawkAppData | Add-Member -MemberType NoteProperty -Name $Name -Value $Value
    }
    else {
        $global:HawkAppData = New-Object -TypeName PSObject
        $global:HawkAppData | Add-Member -MemberType NoteProperty -Name $Name -Value $Value
    }

    # make sure we then write that out to the appdata storage
    Out-HawkAppData

}