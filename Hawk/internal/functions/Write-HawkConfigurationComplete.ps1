Function Write-HawkConfigurationComplete {
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