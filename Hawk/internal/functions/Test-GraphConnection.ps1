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
    General notes
#>

Function Test-GraphConnection {
    # Get tenant details to test that Connect-MgGraph has been called
    try {
        $tenant_details = Get-MgOrganization -All
    } catch {
        Write-Host "You must call Connect-MgGraph before running this script."
        Out-LogFile "Connecting to Graph with scopes: User.Read.All & Directory.Read.All"
	    Connect-MgGraph -Scopes "User.Read.All","Directory.Read.All"
        Select-MgProfile -Name "v1.0"
    }
}
