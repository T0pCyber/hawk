<#
.SYNOPSIS
    Test if we have a connection with the AzureAD Cmdlets
.DESCRIPTION
    Test if we have a connection with the AzureAD Cmdlets
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
Function Test-AzureADConnection {

    $TestModule = Get-Module AzureAD -ListAvailable -ErrorAction SilentlyContinue
    $MinimumVersion = New-Object -TypeName Version -ArgumentList "2.0.0.131"

    if ($null -eq $TestModule) {
        Out-LogFile "Please Install the AzureAD Module with the following command:"
        Out-LogFile "Install-Module AzureAD"
        break
    }
    # Since we are not null pull the highest version
    else {
        $TestModuleVersion = ($TestModule | Sort-Object -Property Version -Descending)[0].version
    }

    # Test the version we need at least 2.0.0.131
    if ($TestModuleVersion -lt $MinimumVersion) {
        Out-LogFile ("AzureAD Module Installed Version: " + $TestModuleVersion)
        Out-LogFile ("Miniumum Required Version: " + $MinimumVersion)
        Out-LogFile "Please update the module with: Update-Module AzureAD"
        break
    }
    # Do nothing
    else { }

    try {
        $Null = Get-AzureADTenantDetail -ErrorAction Stop
    }
    catch [Microsoft.Open.Azure.AD.CommonLibrary.AadNeedAuthenticationException] {
        Out-LogFile "Please connect to AzureAD prior to running this cmdlet"
        Out-LogFile "Connect-AzureAD"
        break
    }
}