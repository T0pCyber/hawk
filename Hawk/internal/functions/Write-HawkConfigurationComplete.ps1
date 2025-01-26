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
        Write-Output ""
        Out-LogFile "====================================================================" -Information
        Out-LogFile "Configuration Complete!" -Information
        Out-LogFile "Your Hawk environment is now set up with the following settings:" -Information
        Out-LogFile ("Hawk Version: " + (Get-Module Hawk).version) -Information

        # Get properties excluding the ones we don't want to display
        $properties = $Hawk.PSObject.Properties | Where-Object { 
            $_.Name -notin @('DaysToLookBack', 'WhenCreated')
        }

        # Format property names and create array of formatted names
        $formattedNames = @()
        foreach ($prop in $properties) {
            $name = $prop.Name -creplace '([A-Z])', ' $1' -replace '_', ' '
            $formattedNames += $name.Trim()
        }

        # Find the longest property name
        $maxLength = ($formattedNames | Measure-Object -Property Length -Maximum).Maximum

        # Output each property with consistent alignment
        for ($i = 0; $i -lt $properties.Count; $i++) {
            $prop = $properties[$i]
            $formattedName = $formattedNames[$i].PadRight($maxLength)
            
            # Get value with N/A fallback
            $value = if ($null -eq $prop.Value -or [string]::IsNullOrEmpty($prop.Value.ToString())) {
                "N/A"
            } else {
                $prop.Value
            }

            Out-LogFile ("{0} : {1}" -f $formattedName, $value) -Information
        }

        Out-LogFile "`Happy Hunting! 🦅" -Information
        Out-LogFile "====================================================================" -Information
        Write-Output ""
    }
}