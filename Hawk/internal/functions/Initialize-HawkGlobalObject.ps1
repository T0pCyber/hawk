﻿Function Initialize-HawkGlobalObject {
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
        
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
        # First test if the path we were given exists
        if (Test-Path $PathToTest) {
            # If the path exists verify that it is a folder
            if ((Get-Item $PathToTest).PSIsContainer -eq $true) {
                Return $true
            }
            # If it is not a folder return false and write an error
            else {
                Write-Information "[$timestamp UTC] [!]  - Path provided $PathToTest was not found to be a folder."
                Return $false
            }
        }
        # If it doesn't exist then return false and write an error
        else {
            Write-Information "[$timestamp UTC] [!]  - Directory $PathToTest Not Found"
            Return $false
        }
    }
    
    Function New-LoggingFolder {
        [CmdletBinding(SupportsShouldProcess)]
        param([string]$RootPath)
    
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
        # Test Graph connection silently first
        $null = Test-GraphConnection 2>$null
    
        # Get tenant name
        $TenantName = (Get-MGDomain -ErrorAction Stop | Where-Object { $_.isDefault }).ID
        [string]$FolderID = "Hawk_" + $TenantName.Substring(0, $TenantName.IndexOf('.')) + "_" + (Get-Date).ToUniversalTime().ToString("yyyyMMdd_HHmm")
    
        $FullOutputPath = Join-Path $RootPath $FolderID
    
        if (Test-Path $FullOutputPath) {
            Write-Information "[$timestamp UTC] [+]   - Path $FullOutputPath already exists"
        }
        else {
            Write-Information "[$timestamp UTC] [-] - Creating subfolder $FullOutputPath"
            $null = New-Item $FullOutputPath -ItemType Directory -ErrorAction Stop
        }
    
        Return $FullOutputPath
    }
    
    Function Set-LoggingPath {
        [CmdletBinding(SupportsShouldProcess)]
        param ([string]$Path)
    
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
        # If no value for Path is provided, prompt and gather from the user
        if ([string]::IsNullOrEmpty($Path)) {
            # Setup a while loop to get a valid path
            Do {
                # Ask the user for the output path
                [string]$UserPath = Read-Host "[$timestamp UTC] [>] - Please provide an output directory"
    
                # If the input is null or empty, prompt again
                if ([string]::IsNullOrEmpty($UserPath)) {
                    Write-Host "[$timestamp UTC] [-] - Directory path cannot be empty. Please enter in a new path."
                    $ValidPath = $false
                }
                # If the path is valid, create the subfolder
                elseif (Test-LoggingPath -PathToTest $UserPath) {
                    $Folder = New-LoggingFolder -RootPath $UserPath
                    $ValidPath = $true
                }
                # If the path is invalid, prompt again
                else {
                    Write-Host "[$timestamp UTC] [!] - Error: Path not a valid directory: $UserPath" -ForegroundColor Red
                    $ValidPath = $false
                }
            }
            While ($ValidPath -eq $false)
        }
        # If a value for Path is provided, validate it
        else {
            # If the provided path is valid, create the subfolder
            if (Test-LoggingPath -PathToTest $Path) {
                $Folder = New-LoggingFolder -RootPath $Path
            }
            # If the provided path fails validation, stop the process
            else {
                Write-Error "[$timestamp UTC] [!] - Error: Provided path is not a valid directory: $Path" -ErrorAction Stop
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
            Out-LogFile "Initializing Application Insights" -Action
            $Client = New-AIClient -key $insightkey
        }
    }

   

    ### Main ###
    $InformationPreference = "Continue"

    if (($null -eq (Get-Variable -Name Hawk -ErrorAction SilentlyContinue)) -or ($Force -eq $true) -or ($null -eq $Hawk)) {

        Write-HawkBanner
        
        # Create the global $Hawk variable immediately with minimal properties
        $Global:Hawk = [PSCustomObject]@{
            FilePath       = $null  # Will be set shortly
            DaysToLookBack = $null
            StartDate      = $null
            EndDate        = $null
            WhenCreated    = $null
        }

        # Set up the file path first, before any other operations
        if ([string]::IsNullOrEmpty($FilePath)) {
            # Suppress Graph connection output during initial path setup
            $Hawk.FilePath = Set-LoggingPath -ErrorAction Stop 2>$null
        }
        else {
            $Hawk.FilePath = Set-LoggingPath -path $FilePath -ErrorAction Stop 2>$null
        }

        # Now that FilePath is set, we can use Out-LogFile
        Out-LogFile "Hawk output directory created at: $($Hawk.FilePath)" -Information
        
        # Setup Application insights
        Out-LogFile "Setting up Application Insights" -Action
        New-ApplicationInsight

        ### Checking for Updates ###
        # If we are skipping the update log it
        if ($SkipUpdate) {
            Out-LogFile -string "Skipping Update Check" -Information
        }
        # Check to see if there is an Update for Hawk
        else {
            Update-HawkModule
        }

        # Test Graph connection
        Out-LogFile "Testing Graph Connection" -Action
        Test-GraphConnection





        # If the global variable Hawk doesn't exist or we have -force then set the variable up
        Out-LogFile -string "Setting Up initial Hawk environment variable" -NoDisplay

        try {
            $LicenseInfo = Test-LicenseType
            $MaxDaysToGoBack = $LicenseInfo.RetentionPeriod
            $LicenseType = $LicenseInfo.LicenseType

            Out-LogFile -string "Detecting M365 license type to determine maximum log retention period" -action
            Out-LogFile -string "M365 License type detected: $LicenseType" -Information
            Out-LogFile -string "Max log retention: $MaxDaysToGoBack days" -action -NoNewLine

        } catch {
            Out-LogFile -string "Failed to detect license type. Max days of log retention is unknown." -Information
            $MaxDaysToGoBack = 90
            $LicenseType = "Unknown"
        }

        # Ensure MaxDaysToGoBack does not exceed 365 days
        if ($MaxDaysToGoBack -gt 365) { $MaxDaysToGoBack = 365 }

        # Prompt for Start Date if not set
        while ($null -eq $StartDate) {

            # Read input from user
            Write-Output "`n"
            Out-LogFile "Please specify the first day of the search window:" -isPrompt
            Out-LogFile " Enter a number of days to go back (1-$MaxDaysToGoBack)" -isPrompt
            Out-LogFile " OR enter a date in MM/DD/YYYY format" -isPrompt
            Out-LogFile " Default is 90 days back: " -isPrompt -NoNewLine
            $StartRead = Read-Host
            

            # Determine if input is a valid date
            if ($null -eq ($StartRead -as [DateTime])) {

                #### Not a DateTime ####
                if ([string]::IsNullOrEmpty($StartRead)) {
                    $StartRead = 90
                }

                # Validate the entered days back
                if ($StartRead -gt $MaxDaysToGoBack) {
                    Out-LogFile -string "You have entered a time frame greater than your license allows ($MaxDaysToGoBack days)." -isWarning
                    $Proceed = Read-Host "Press ENTER to proceed or type 'R' to re-enter the value"
                    if ($Proceed -eq 'R') { continue }
                }

                if ($StartRead -gt 365) {
                    Out-LogFile -string "Log retention cannot exceed 365 days. Setting retention to 365 days." -isWarning
                    $StartRead = 365
                }

                # Calculate start date
                [DateTime]$StartDate = ((Get-Date).ToUniversalTime().AddDays(-$StartRead)).Date
                Write-Output ""
                Out-LogFile -string "Start date set to: $StartDate [UTC]" -Information -NoNewLine

            } elseif (!($null -eq ($StartRead -as [DateTime]))) {

                #### DateTime Provided ####
                [DateTime]$StartDate = (Get-Date $StartRead).ToUniversalTime().Date

                # Validate the date
                if ($StartDate -lt ((Get-Date).ToUniversalTime().AddDays(-$MaxDaysToGoBack))) {
                    Out-LogFile -string "The date entered exceeds your license retention period of $MaxDaysToGoBack days." -isWarning
                    $Proceed = Read-Host "Press ENTER to proceed or type 'R' to re-enter the date"
                    if ($Proceed -eq 'R') { $StartDate = $null; continue }
                }

                if ($StartDate -lt ((Get-Date).ToUniversalTime().AddDays(-365))) {
                    Out-LogFile -string "The date cannot exceed 365 days. Setting to the maximum limit of 365 days." -isWarning
                    [DateTime]$StartDate = ((Get-Date).ToUniversalTime().AddDays(-365)).Date
                }

                Out-LogFile -string "Start Date (UTC): $StartDate" -Information

            } else {
                Out-LogFile -string "Invalid date information provided. Could not determine if this was a date or an integer." -isError
                break
            }
        }

        # End date logic remains unchanged
        if ($null -eq $EndDate) {
            Write-Output "`n"
            Out-LogFile "Please specify the last day of the search window:" -isPrompt
            Out-LogFile " Enter a number of days to go back from today (1-365)" -isPrompt
            Out-LogFile " OR enter a specific date in MM/DD/YYYY format" -isPrompt 
            Out-LogFile " Default is today's date:" -isPrompt -NoNewLine
            $EndRead = Read-Host            

            # End date validation
            if ($null -eq ($EndRead -as [DateTime])) {
                if ([string]::IsNullOrEmpty($EndRead)) {
                    [DateTime]$EndDate = (Get-Date).ToUniversalTime().Date
                } else {
                    Out-LogFile -string "End Date (UTC): $EndRead days." -Information
                    [DateTime]$EndDate = ((Get-Date).ToUniversalTime().AddDays(-($EndRead - 1))).Date
                }

                if ($StartDate -gt $EndDate) {
                    Out-LogFile -string "StartDate cannot be more recent than EndDate" -isError
                } else {
                    Write-Output ""
                    Out-LogFile -string "End date set to: $EndDate [UTC]`n" -Information
                }
            } elseif (!($null -eq ($EndRead -as [DateTime]))) {
                [DateTime]$EndDate = (Get-Date $EndRead).ToUniversalTime().Date

                if ($StartDate -gt $EndDate) {
                    Out-LogFile -string "EndDate is earlier than StartDate. Setting EndDate to today." -isWarning
                    [DateTime]$EndDate = (Get-Date).ToUniversalTime().Date
                } elseif ($EndDate -gt ((Get-Date).ToUniversalTime().AddDays(1))) {
                    Out-LogFile -string "EndDate too far in the future. Setting EndDate to today." -isWarning
                    [DateTime]$EndDate = (Get-Date).ToUniversalTime().Date
                }

                Out-LogFile -string "End date set to: $EndDate [UTC]`n" -Information
            } else {
                Out-LogFile -string "Invalid date information provided. Could not determine if this was a date or an integer." -isError
            }
        }

        # Configuration Example, currently not used
        #TODO: Implement Configuration system across entire project
        Set-PSFConfig -Module 'Hawk' -Name 'DaysToLookBack' -Value $Days -PassThru | Register-PSFConfig
        if ($OutputPath) {
            Set-PSFConfig -Module 'Hawk' -Name 'FilePath' -Value $OutputPath -PassThru | Register-PSFConfig
        }

        # Continue populating the Hawk object with other properties
        $Hawk.DaysToLookBack = $Days
        $Hawk.StartDate = $StartDate
        $Hawk.EndDate = $EndDate
        $Hawk.WhenCreated = (Get-Date).ToUniversalTime().ToString("g")

        Write-HawkConfigurationComplete -Hawk $Hawk 


    }
    else {
        Out-LogFile -string "Valid Hawk Object already exists no actions will be taken." -Information
    }
}
