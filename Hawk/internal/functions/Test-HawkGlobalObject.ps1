Function Test-HawkGlobalObject {
    <#
    .SYNOPSIS
        Tests if the Hawk global object exists and is properly initialized.
    
    .DESCRIPTION
        This is an internal helper function that verifies whether the Hawk global object 
        exists and contains all required properties properly initialized. It checks for:
        - FilePath property existence and value
        - StartDate property existence and value
        - EndDate property existence and value
        - Domain property existence and value
    
    .EXAMPLE
        Test-HawkGlobalObject
        Returns $true if Hawk object is properly initialized, $false otherwise.
    
    .OUTPUTS 
        Boolean indicating if reinitialization is needed
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Return true (needs initialization) if:
    # - Hawk object doesn't exist 
    # - Any required property is missing or null
    if ([string]::IsNullOrEmpty($Hawk.FilePath) -or 
        $null -eq $Hawk.StartDate -or 
        $null -eq $Hawk.EndDate -or 
        [string]::IsNullOrEmpty($Hawk.Domain) -or
        ($Hawk.PSObject.Properties.Name -contains 'StartDate' -and $null -eq $Hawk.StartDate) -or
        ($Hawk.PSObject.Properties.Name -contains 'EndDate' -and $null -eq $Hawk.EndDate) -or
        ($Hawk.PSObject.Properties.Name -contains 'Domain' -and [string]::IsNullOrEmpty($Hawk.Domain))) {
        return $true
    }

    # Hawk object exists and is properly initialized
    return $false
}