Function Write-HawkConfigurationComplete {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Hawk
    )

    Out-LogFile "Configuration Complete!" -Information
    Out-LogFile "Your Hawk environment is now set up with the following settings:" -action
    Out-LogFile ("Hawk Version: " + (Get-Module Hawk).version) -Action

    # Print each property of $Hawk on its own line
    foreach ($prop in $Hawk.PSObject.Properties) {
        # If the property value is $null or an empty string, display "N/A"
        $value = if ($null -eq $prop.Value -or [string]::IsNullOrEmpty($prop.Value.ToString())) {
            "N/A"
        } else {
            $prop.Value
        }

        Out-LogFile -string ("{0} = {1}" -f $prop.Name, $value) -action
    }

    Out-LogFile "`Happy hunting! 🦅`n" -action
}
