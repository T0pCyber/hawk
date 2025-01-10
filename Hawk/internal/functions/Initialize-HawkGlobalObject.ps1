Function Initialize-HawkGlobalObject {
    <#
    .SYNOPSIS
        Create global variable $Hawk for use by all Hawk cmdlets.
    .DESCRIPTION
        Creates the global variable $Hawk and populates it with information needed by the other Hawk cmdlets.

        * Checks for latest version of the Hawk module
        * Creates path for output files
        * Records target start and end dates for searches (in UTC)
    .PARAMETER Force
        Switch to force the function to run and allow the variable to be recreated
    .PARAMETER SkipUpdate
        Skips checking for the latest version of the Hawk Module
    .PARAMETER DaysToLookBack
        Defines the # of days to look back in the availible logs.
        Valid values are 1-90
    .PARAMETER StartDate
        First day that data will be retrieved (in UTC)
    .PARAMETER EndDate
        Last day that data will be retrieved (in UTC)
    .PARAMETER FilePath
        Provide an output file path.
    .OUTPUTS
        Creates the $Hawk global variable and populates it with a custom PS object with the following properties

        Property Name	Contents
        ==========		==========
        FilePath		Path to output files
        DaysToLookBack	Number of day back in time we are searching
        StartDate		Calculated start date for searches based on DaysToLookBack (UTC)
        EndDate			One day in the future (UTC)
        WhenCreated		Date and time that the variable was created (UTC)
    .EXAMPLE
        Initialize-HawkGlobalObject -Force

        This Command will force the creation of a new $Hawk variable even if one already exists.
    #>
    [CmdletBinding()]
    param
    (
        [switch]$Force,
        [switch]$SkipUpdate,
        [DateTime]$StartDate,
        [DateTime]$EndDate,
        [string]$FilePath
    )

    Function Test-LoggingPath {
        param([string]$PathToTest)

        # First test if the path we were given exists
        if (Test-Path $PathToTest) {

            # If the path exists verify that it is a folder
            if ((Get-Item $PathToTest).PSIsContainer -eq $true) {
                Return $true
            }
            # If it is not a folder return false and write an error
            else {
                Write-Information ("Path provided " + $PathToTest + " was not found to be a folder.")
                Return $false
            }
        }
        # If it doesn't exist then return false and write an error
        else {
            Write-Information ("Directory " + $PathToTest + " Not Found")
            Return $false
        }
    }

    Function New-LoggingFolder {
        [CmdletBinding(SupportsShouldProcess)]
        param([string]$RootPath)

        # Create a folder ID based on UTC date
        [string]$TenantName = (Get-MGDomain | Where-Object { $_.isDefault }).ID
        [string]$FolderID = "Hawk_" + $TenantName.Substring(0, $TenantName.IndexOf('.')) + "_" + (Get-Date).ToUniversalTime().ToString("yyyyMMdd_HHmm")

        # Add that ID to the given path
        $FullOutputPath = Join-Path $RootPath $FolderID

        # Just in case we run this twice in a min lets not throw an error
        if (Test-Path $FullOutputPath) {
            Write-Information "Path Exists"
        }
        # If it is not there make it
        else {
            Write-Information ("Creating subfolder with name " + $FullOutputPath)
            $null = New-Item $FullOutputPath -ItemType Directory
        }

        Return $FullOutputPath
    }

    Function Set-LoggingPath {
        [CmdletBinding(SupportsShouldProcess)]
        param ([string]$Path)

        # If no value of Path is provided prompt and gather from the user
        if ([string]::IsNullOrEmpty($Path)) {

            # Setup a while loop so we can get a valid path
            Do {

                # Ask the customer for the output path
                [string]$UserPath = Read-Host "Please provide an output directory"

                # If the path is valid then create the subfolder
                if (Test-LoggingPath -PathToTest $UserPath) {

                    $Folder = New-LoggingFolder -RootPath $UserPath
                    $ValidPath = $true
                }
                # If the path if not valid then we need to loop thru again
                else {
                    Write-Information ("Path not a valid Directory " + $UserPath)
                    $ValidPath = $false
                }

            }
            While ($ValidPath -eq $false)
        }
        # If a value if provided go from there
        else {
            # If the provided path is valid then we can create the subfolder
            if (Test-LoggingPath -PathToTest $Path) {
                $Folder = New-LoggingFolder -RootPath $Path
            }
            # If the provided path fails validation then we just need to stop
            else {
                Write-Error ("Provided Path is not valid " + $Path) -ErrorAction Stop
            }
        }

        Return $Folder
    }

    Function New-ApplicationInsight {
        [CmdletBinding(SupportsShouldProcess)]
        param()
        # Initialize Application Insights client
        $insightkey = "b69ffd8b-4569-497c-8ee7-b71b8257390e"
        if ($Null -eq $Client) {
            Write-Output "Initializing Application Insights"
            $Client = New-AIClient -key $insightkey
        }
    }

    ### Main ###
    $InformationPreference = "Continue"

    if (($null -eq (Get-Variable -Name Hawk -ErrorAction SilentlyContinue)) -or ($Force -eq $true) -or ($null -eq $Hawk)) {

        # Setup Applicaiton insights
        New-ApplicationInsight

        ### Checking for Updates ###
        # If we are skipping the update log it
        if ($SkipUpdate) {
            Write-Information "Skipping Update Check"
        }
        # Check to see if there is an Update for Hawk
        else {
            Update-HawkModule
        }

        # Test if we have a connection to Microsoft Graph
        Write-Information "Testing Graph Connection"
        Test-GraphConnection

        # If the global variable Hawk doesn't exist or we have -force then set the variable up
        Write-Information "Setting Up initial Hawk environment variable"

        #### Checking log path and setting up subdirectory ###
        # If we have a path passed in then we need to check that otherwise ask
        if ([string]::IsNullOrEmpty($FilePath)) {
            [string]$OutputPath = Set-LoggingPath
        }
        else {
            [string]$OutputPath = Set-LoggingPath -path $FilePath
        }

        try {
            $LicenseInfo = Test-LicenseType
            $MaxDaysToGoBack = $LicenseInfo.RetentionPeriod
            $LicenseType = $LicenseInfo.LicenseType
        
            Write-Information "Detecting M365 license type to determine maximum log retention period" 
            Write-Information "M365 License type detected: $LicenseType"
            Write-Information "Max log retention: $MaxDaysToGoBack days"
        
        } catch {
            Write-Information "Failed to detect license type. Max days of log retention is unknown." 
            $MaxDaysToGoBack = 90
            $LicenseType = "Unknown"
        }
        
        # Ensure MaxDaysToGoBack does not exceed 365 days
        if ($MaxDaysToGoBack -gt 365) { $MaxDaysToGoBack = 365 }
        
        # Prompt for Start Date if not set
        while ($null -eq $StartDate) {
        
            # Read input from user
            Write-Output "`nPlease specify the first day of the search window:"
            Write-Output " - Enter a number of days to go back (1-$MaxDaysToGoBack)"
            Write-Output " - OR enter a date in MM/DD/YYYY format"
            $StartRead = Read-Host "Default is 90 days back"
                    
            # Determine if input is a valid date
            if ($null -eq ($StartRead -as [DateTime])) {
        
                #### Not a DateTime ####
                if ([string]::IsNullOrEmpty($StartRead)) { 
                    $StartRead = 90 
                }
        
                # Validate the entered days back
                if ($StartRead -gt $MaxDaysToGoBack) {
                    Write-Warning "You have entered a time frame greater than your license allows ($MaxDaysToGoBack days)."
                    $Proceed = Read-Host "Press ENTER to proceed or type 'R' to re-enter the value"
                    if ($Proceed -eq 'R') { continue }
                }
        
                if ($StartRead -gt 365) {
                    Write-Warning "Log retention cannot exceed 365 days. Setting retention to 365 days."
                    $StartRead = 365
                }
        
                # Calculate start date
                [DateTime]$StartDate = ((Get-Date).ToUniversalTime().AddDays(-$StartRead)).Date
                Write-Information "Start Date (UTC): $StartDate"
        
            } elseif (!($null -eq ($StartRead -as [DateTime]))) {
        
                #### DateTime Provided ####
                [DateTime]$StartDate = (Get-Date $StartRead).ToUniversalTime().Date
        
                # Validate the date
                if ($StartDate -lt ((Get-Date).ToUniversalTime().AddDays(-$MaxDaysToGoBack))) {
                    Write-Warning "The date entered exceeds your license retention period of $MaxDaysToGoBack days."
                    $Proceed = Read-Host "Press ENTER to proceed or type 'R' to re-enter the date"
                    if ($Proceed -eq 'R') { $StartDate = $null; continue }
                }
        
                if ($StartDate -lt ((Get-Date).ToUniversalTime().AddDays(-365))) {
                    Write-Warning "The date cannot exceed 365 days. Setting to the maximum limit of 365 days."
                    [DateTime]$StartDate = ((Get-Date).ToUniversalTime().AddDays(-365)).Date
                }
        
                Write-Information "Start Date (UTC): $StartDate"
        
            } else {
                Write-Error "Invalid date information provided. Could not determine if this was a date or an integer." -ErrorAction Stop
            }
        }

        # End date logic remains unchanged
        if ($null -eq $EndDate) {
            Write-Output "`nPlease specify the last day of the search window:"
            Write-Output " - Enter a number of days to go back from today (1-365)"
            Write-Output " - OR enter a specific date in MM/DD/YYYY format"
            $EndRead = Read-Host "Default is today's date"
            
            

            # End date validation
            if ($null -eq ($EndRead -as [DateTime])) {
                if ([string]::IsNullOrEmpty($EndRead)) {
                    [DateTime]$EndDate = (Get-Date).ToUniversalTime().Date
                } else {
                    Write-Information "End Date (UTC): $EndRead days."
                    [DateTime]$EndDate = ((Get-Date).ToUniversalTime().AddDays(-($EndRead - 1))).Date
                }

                if ($StartDate -gt $EndDate) {
                    Write-Error "StartDate cannot be more recent than EndDate" -ErrorAction Stop
                } else {
                    Write-Information "End Date (UTC): $EndDate`n"
                }
            } elseif (!($null -eq ($EndRead -as [DateTime]))) {
                [DateTime]$EndDate = (Get-Date $EndRead).ToUniversalTime().Date

                if ($StartDate -gt $EndDate) {
                    Write-Warning "EndDate is earlier than StartDate. Setting EndDate to today."
                    [DateTime]$EndDate = (Get-Date).ToUniversalTime().Date
                } elseif ($EndDate -gt ((Get-Date).ToUniversalTime().AddDays(1))) {
                    Write-Warning "EndDate too far in the future. Setting EndDate to today."
                    [DateTime]$EndDate = (Get-Date).ToUniversalTime().Date
                }

                Write-Information "End Date (UTC): $EndDate`n"
            } else {
                Write-Error "Invalid date information provided. Could not determine if this was a date or an integer." -ErrorAction Stop
            }
        }

        # Configuration Example, currently not used
        #TODO: Implement Configuration system across entire project
        Set-PSFConfig -Module 'Hawk' -Name 'DaysToLookBack' -Value $Days -PassThru | Register-PSFConfig
        if ($OutputPath) {
            Set-PSFConfig -Module 'Hawk' -Name 'FilePath' -Value $OutputPath -PassThru | Register-PSFConfig
        }

        #TODO: Discard below once migration to configuration is completed
        $Output = [PSCustomObject]@{
            FilePath             = $OutputPath
            DaysToLookBack       = $Days
            StartDate           = $StartDate
            EndDate             = $EndDate
            MaxDays             = $MaxDaysToGoBack
            WhenCreated         = (Get-Date).ToUniversalTime().ToString("g")
        }

        # Create the script hawk variable
        Write-Information "Setting up Script Hawk environment variable`n"
        New-Variable -Name Hawk -Scope Script -value $Output -Force
        Out-LogFile "Script Variable Configured" -Information
        Out-LogFile ("Hawk Version: " + (Get-Module Hawk).version) -Information
        
        # Print each property of $Hawk on its own line
        foreach ($prop in $Hawk.PSObject.Properties) {
            # If the property value is $null or an empty string, display "N/A"
            $value = if ($null -eq $prop.Value -or [string]::IsNullOrEmpty($prop.Value.ToString())) {
                "N/A"
            } else {
                $prop.Value
            }
        
            Out-LogFile ("{0} = {1}" -f $prop.Name, $value) -Information
        }
    }
    else {
        Write-Information "Valid Hawk Object already exists no actions will be taken."
    }
}