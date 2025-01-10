Function Write-HawkConfigurationComplete {
    <#
    .SYNOPSIS
        Displays the completed Hawk configuration settings.
    
    .DESCRIPTION
        Outputs a summary of all configured Hawk settings after initialization is complete.
        This includes version information and all properties of the Hawk configuration object,
        formatted for easy reading. Null or empty values are displayed as "N/A".
    
    .PARAMETER Hawk
        A PSCustomObject containing the Hawk configuration settings. This object must include
        properties for FilePath, DaysToLookBack, StartDate, EndDate, and other required
        configuration values.
    
    .EXAMPLE
        PS C:\> Write-HawkConfigurationComplete -Hawk $Hawk
        
        Displays the complete Hawk configuration settings from the provided Hawk object,
        including file paths, date ranges, and version information.
    
    .EXAMPLE
        PS C:\> $config = Initialize-HawkGlobalObject
        PS C:\> Write-HawkConfigurationComplete -Hawk $config
        
        Initializes a new Hawk configuration and displays the complete settings.
    
    .NOTES
        This function is typically called automatically after Hawk initialization
        but can be run manually to review current settings.
    #>
        [CmdletBinding()]
        param (
            [Parameter(
                Mandatory = $true,
                Position = 0,
                ValueFromPipeline = $true,
                HelpMessage = "PSCustomObject containing Hawk configuration settings"
            )]
            [PSCustomObject]$Hawk
        )
    
        process {
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
    }