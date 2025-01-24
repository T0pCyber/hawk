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
    .PARAMETER NonInteractive
    Switch to run the command in non-interactive mode. Requires all necessary parameters
    to be provided via command line rather than through interactive prompts.
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
        [DateTime]$StartDate,
        [DateTime]$EndDate,
        [int]$DaysToLookBack,
        [string]$FilePath,
        [switch]$SkipUpdate,
        [switch]$NonInteractive,
        [switch]$Force
    )


    if ($Force) {
        Remove-Variable -Name Hawk -Scope Global -ErrorAction SilentlyContinue 
    }

    # Check for incomplete/interrupted initialization and force a fresh start
    if ($null -ne (Get-Variable -Name Hawk -ErrorAction SilentlyContinue)) {
        if (Test-HawkGlobalObject) {
            Remove-Variable -Name Hawk -Scope Global -ErrorAction SilentlyContinue
            
            # Remove other related global variables that might exist
            Remove-Variable -Name IPlocationCache -Scope Global -ErrorAction SilentlyContinue
            Remove-Variable -Name MSFTIPList -Scope Global -ErrorAction SilentlyContinue
        }
    }

    Function Test-LoggingPath {
        param([string]$PathToTest)
        
        # Get the current timestamp in the format yyyy-MM-dd HH:mm:ssZ
        $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss'Z'")
    
        # First test if the path we were given exists
        if (Test-Path $PathToTest) {
            # If the path exists verify that it is a folder
            if ((Get-Item $PathToTest).PSIsContainer -eq $true) {
                Return $true
            }
            # If it is not a folder return false and write an error
            else {
                Write-Information "[$timestamp] - [ERROR]  - Path provided $PathToTest was not found to be a folder."
                Return $false
            }
        }
        # If it doesn't exist then return false and write an error
        else {
            Write-Information "[$timestamp] - [ERROR]  - Directory $PathToTest Not Found"
            Return $false
        }
    }
    
    Function New-LoggingFolder {
        [CmdletBinding(SupportsShouldProcess)]
        param([string]$RootPath)
   
        # Get the current timestamp in the format yyyy-MM-dd HH:mm:ssZ
        $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss'Z'")
    
        try {
            # Test Graph connection first to see if we're already connected
            try {
                $null = Get-MgOrganization -ErrorAction Stop
                Write-Information "[$timestamp] - [INFO]   - Already connected to Microsoft Graph"
            }
            catch {
                # Only show connecting message if we actually need to connect
                Write-Information "[$timestamp] - [ACTION] - Connecting to Microsoft Graph"
                $null = Test-GraphConnection
                Write-Information "[$timestamp] - [INFO]   - Connected to Microsoft Graph Successfully"
            }
    
            # Get tenant name 
            $TenantName = (Get-MGDomain -ErrorAction Stop | Where-Object { $_.isDefault }).ID
            [string]$FolderID = "Hawk_" + $TenantName.Substring(0, $TenantName.IndexOf('.')) + "_" + (Get-Date).ToUniversalTime().ToString("yyyyMMdd_HHmmss")
    
            $FullOutputPath = Join-Path $RootPath $FolderID
    
            if (Test-Path $FullOutputPath) {
                Write-Information "[$timestamp] - [ERROR]  - Path $FullOutputPath already exists"
            }
            else {
                Write-Information "[$timestamp] - [ACTION] - Creating subfolder $FullOutputPath"
                $null = New-Item $FullOutputPath -ItemType Directory -ErrorAction Stop
            }
    
            Return $FullOutputPath

        }
        catch {
            # If it fails at any point, display an error message
            Write-Error "[$timestamp] - [ERROR]  - Failed to create logging folder: $_"
        }
    }
    
    Function Set-LoggingPath {
        [CmdletBinding(SupportsShouldProcess)]
        param (
            [string]$Path)
    
        # Get the current timestamp in the format yyyy-MM-dd HH:mm:ssZ
        $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss'Z'")
    
        # If no value for Path is provided, prompt and gather from the user
        if ([string]::IsNullOrEmpty($Path)) {
            # Setup a while loop to get a valid path
            Do {
                # Ask the user for the output path
                [string]$UserPath = (Read-Host "[$timestamp] - [PROMPT] - Please provide an output directory").Trim()
    
                # If the input is null or empty, prompt again
                if ([string]::IsNullOrEmpty($UserPath)) {
                    Write-Host "[$timestamp] - [INFO]   - Directory path cannot be empty. Please enter in a new path."
                    $ValidPath = $false
                }
                # If the path is valid, create the subfolder
                elseif (Test-LoggingPath -PathToTest $UserPath) {
                    $Folder = New-LoggingFolder -RootPath $UserPath
                    $ValidPath = $true
                }
                # If the path is invalid, prompt again
                else {
                    Write-Information "[$timestamp] - [ERROR]  - Path not a valid directory: $UserPath"
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
                Write-Error "[$timestamp] - [ERROR]  - Provided path is not a valid directory: $Path"
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

        if ($NonInteractive) {
            Write-HawkBanner
        } else {
            Write-HawkBanner -DisplayWelcomeMessage
        }
        
        
        
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
            $Hawk.FilePath = Set-LoggingPath -ErrorAction Stop
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


        if (-not $NonInteractive) {
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
    
        }


        # Ensure MaxDaysToGoBack does not exceed 365 days
        if ($MaxDaysToGoBack -gt 365) { $MaxDaysToGoBack = 365 }

        # Start date validation: Add check for negative numbers
        while ($null -eq $StartDate) {
            Write-Output "`n"
            Out-LogFile "Please specify the first day of the search window:" -isPrompt
            Out-LogFile " Enter a number of days to go back (1-$MaxDaysToGoBack)" -isPrompt 
            Out-LogFile " OR enter a date in MM/DD/YYYY format" -isPrompt
            Out-LogFile " Default is 90 days back: " -isPrompt -NoNewLine
            $StartRead = (Read-Host).Trim()
        
            # Determine if input is a valid date
            if ($null -eq ($StartRead -as [DateTime])) {
                
                #### Not a DateTime => interpret as # of days ####
                if ([string]::IsNullOrEmpty($StartRead)) {
                    [int]$StartRead = 90
                }
                # Validates the input is an integer
                elseif ($StartRead -match '^\d+$') {
                    # Only convert to int if it is a valid positive number
                    [int]$StartRead = [int]$StartRead
                }
                else {
                    Out-LogFile -string "Invalid input. Please enter a number between 1 and 365, or a date in MM/DD/YYYY format." -isError
                    continue
                }
        
                # We store this integer in $StartDays so we can potentially re-anchor from EndDate later
                $StartDays = $StartRead
        
                # Validate the input is within range
                if (($StartRead -gt 365) -or ($StartRead -lt 1))   {
                    Out-LogFile -string "Days to go back must be between 1 and 365." -isError
                    continue
                }


                # Validate the entered days back
                if ([int]$StartRead -gt [int]$MaxDaysToGoBack) {
                    Out-LogFile -string "You have entered a time frame greater than your license allows ($MaxDaysToGoBack days)." -isWarning
                    Out-LogFile "Press ENTER to proceed or type 'R' to re-enter the value: " -isPrompt -NoNewLine
                    $Proceed = (Read-Host).Trim()
                    if ($Proceed -eq 'R') { continue }
                }

        
                # At this point, we do not yet have EndDate set. So temporarily anchor from "today":
                [DateTime]$StartDate = ((Get-Date).ToUniversalTime().AddDays(-$StartRead)).Date
        
                Out-LogFile -string "Start date set to: ${StartDate}Z" -Information
        
            }
            elseif (!($null -eq ($StartRead -as [DateTime]))) {
                [DateTime]$StartDate = $StartRead -as [DateTime]  # <--- Add this line

                # ========== The user entered a DateTime, so $StartDays stays 0 ==========
                # Validate the date
                if ($StartDate -gt (Get-Date).ToUniversalTime()) {
                    Out-LogFile -string "Start date cannot be in the future." -isError
                    Remove-Variable -Name StartDate -ErrorAction SilentlyContinue
                    continue
                }

                if ($StartDate -lt ((Get-Date).ToUniversalTime().AddDays(-$MaxDaysToGoBack))) {
                    Out-LogFile -string "The date entered exceeds your license retention period of $MaxDaysToGoBack days." -isWarning
                    Out-LogFile "Press ENTER to proceed or type 'R' to re-enter the date:" -isPrompt -NoNewLine
                    $Proceed = (Read-Host).Trim()
                    if ($Proceed -eq 'R') { $StartDate = $null; continue }
                }
                

                if ($StartDate -lt ((Get-Date).ToUniversalTime().AddDays(-365))) {
                    Out-LogFile -string "The date cannot exceed 365 days. Setting to the maximum limit of 365 days." -isWarning
                    [DateTime]$StartDate = ((Get-Date).ToUniversalTime().AddDays(-365)).Date

                }

                Out-LogFile -string "Start Date: ${StartDate}Z" -Information
            }
            else {
                Out-LogFile -string "Invalid date information provided. Could not determine if this was a date or an integer." -isError
                $StartDate = $null
                continue
            }
        }

        # End date logic with enhanced validation
        while ($null -eq $EndDate) {
            Write-Output "`n"
            Out-LogFile "Please specify the last day of the search window:" -isPrompt
            Out-LogFile " Enter a number of days to go back from today (1-365)" -isPrompt
            Out-LogFile " OR enter a specific date in MM/DD/YYYY format" -isPrompt
            Out-LogFile " Default is today's date:" -isPrompt -NoNewLine
            $EndRead = (Read-Host).Trim()

            # End date validation
            if ($null -eq ($EndRead -as [DateTime])) {
                if ([string]::IsNullOrEmpty($EndRead)) {
                    [DateTime]$tempEndDate = (Get-Date).ToUniversalTime().Date
                }
                else {
                    # Validate input is a positive number
                    if ($EndRead -match '^\-') {
                        Out-LogFile -string "Please enter a positive number of days." -isError
                        continue
                    }
                    # Validate numeric value
                    if ($EndRead -notmatch '^\d+$') {
                        Out-LogFile -string "Invalid input. Please enter a number between 1 and 365, or a date in MM/DD/YYYY format." -isError
                        continue
                    }
                    Out-LogFile -string "End Date: $EndRead days." -Information
                    [DateTime]$tempEndDate = ((Get-Date).ToUniversalTime().AddDays(-($EndRead - 1))).Date
                }

                if ($StartDate -gt $tempEndDate) {
                    Out-LogFile -string "End date must be more recent than start date ($StartDate)." -isError
                    continue
                }

                # --- FINAL FIX: Always move to next day at 00:00 UTC ---
                $tempEndDate = $tempEndDate.ToUniversalTime().Date.AddDays(1)

                $EndDate = $tempEndDate
                # Write-Output ""
                # Out-LogFile -string "End date set to: ${EndDate}Z`n" -Information
            }
            elseif (!($null -eq ($EndRead -as [DateTime]))) {

                [DateTime]$tempEndDate = (Get-Date $EndRead).ToUniversalTime().Date

                if ($StartDate -gt $tempEndDate) {
                    Out-LogFile -string "End date must be more recent than start date ($StartDate)." -isError
                    continue
                }
                elseif ($tempEndDate -gt ((Get-Date).ToUniversalTime().AddDays(1))) {
                    Out-LogFile -string "EndDate too far in the future. Setting EndDate to today." -isWarning
                    $tempEndDate = (Get-Date).ToUniversalTime().Date
                }

                # --- FINAL FIX: Always move to next day at 00:00 UTC ---
                $tempEndDate = $tempEndDate.ToUniversalTime().Date.AddDays(1)

                $EndDate = $tempEndDate
                # Out-LogFile -string "End date set to: ${EndDate}Z`n" -Information
            }
            else {
                Out-LogFile -string "Invalid date information provided. Could not determine if this was a date or an integer." -isError
                continue
            }
        }

        # End date logic remains unchanged except for final +1 day fix
        if ($null -eq $EndDate) {
            Write-Output "`n"
            Out-LogFile "Please specify the last day of the search window:" -isPrompt
            Out-LogFile " Enter a number of days to go back from today (1-365)" -isPrompt
            Out-LogFile " OR enter a specific date in MM/DD/YYYY format" -isPrompt
            Out-LogFile " Default is today's date:" -isPrompt -NoNewLine
            $EndRead = (Read-Host).Trim()            

            # End date validation
            if ($null -eq ($EndRead -as [DateTime])) {
                if ([string]::IsNullOrEmpty($EndRead)) {
                    [DateTime]$EndDate = (Get-Date).ToUniversalTime().Date
                } else {
                    Out-LogFile -string "End Date: $EndRead days." -Information
                    [DateTime]$EndDate = ((Get-Date).ToUniversalTime().AddDays(-($EndRead - 1))).Date
                }

                if ($StartDate -gt $EndDate) {
                    Out-LogFile -string "StartDate cannot be more recent than EndDate" -isError
                }
                else {
                    # --- FINAL FIX: Always move to next day at 00:00 UTC ---
                    $EndDate = $EndDate.ToUniversalTime().Date.AddDays(1)

                    # Write-Output ""
                    # Out-LogFile -string "End date set to: ${EndDate}Z`n" -Information
                }
            }
            elseif (!($null -eq ($EndRead -as [DateTime]))) {
                [DateTime]$EndDate = (Get-Date $EndRead).ToUniversalTime().Date

                if ($StartDate -gt $EndDate) {
                    Out-LogFile -string "EndDate is earlier than StartDate. Setting EndDate to today." -isWarning
                    [DateTime]$EndDate = (Get-Date).ToUniversalTime().Date
                }
                elseif ($EndDate -gt ((Get-Date).ToUniversalTime().AddDays(1))) {
                    Out-LogFile -string "EndDate too far in the future. Setting EndDate to today." -isWarning
                    [DateTime]$EndDate = (Get-Date).ToUniversalTime().Date
                }

                # --- FINAL FIX: Always move to next day at 00:00 UTC ---
                $EndDate = $EndDate.ToUniversalTime().Date.AddDays(1)

                # Out-LogFile -string "End date set to: ${EndDate}Z`n" -Information
            }
            else {
                Out-LogFile -string "Invalid date information provided. Could not determine if this was a date or an integer." -isError
            }
        }

        # --- AFTER the EndDate block, do a final check to "re-anchor" StartDate if it was given in days ---
        if ($StartDays -gt 0) {
            # Recalculate StartDate based on EndDate = $EndDate and StartDays = $StartDays
            Out-LogFile -string "End date set to midnight UTC of next day to include all data from $($EndDate.AddDays(-1).Date.ToString('yyyy-MM-dd'))Z`n" -Information
            $StartDate = $EndDate.ToUniversalTime().AddDays(-$StartDays).Date

            # (Optional) Additional validations again if necessary:
            if ($StartDate -gt (Get-Date).ToUniversalTime()) {
                Out-LogFile -string "Start date is in the future. Resetting to today's date." -isWarning
                $StartDate = (Get-Date).ToUniversalTime().Date
            }

            # If EndDate is today, adjust to current time
            if ($EndDate.Date -eq (Get-Date).Date) {
                $EndDate = (Get-Date).ToUniversalTime()
                Out-LogFile -string "Adjusting EndDate to current time: $EndDate" -Information
            }

        }



        # Configuration Example, currently not used
        #TODO: Implement Configuration system across entire project
        Set-PSFConfig -Module 'Hawk' -Name 'DaysToLookBack' -Value $Days -PassThru | Register-PSFConfig
        if ($OutputPath) {
            Set-PSFConfig -Module 'Hawk' -Name 'FilePath' -Value $OutputPath -PassThru | Register-PSFConfig
        }

        # Continue populating the Hawk object with other properties
        $Hawk.DaysToLookBack = $DaysToLookBack
        $Hawk.StartDate = $StartDate
        $Hawk.EndDate = $EndDate
        $Hawk.WhenCreated = (Get-Date).ToUniversalTime().ToString("g")

        Write-HawkConfigurationComplete -Hawk $Hawk 


    }
    else {
        Out-LogFile -string "Valid Hawk Object already exists no actions will be taken." -Information
    }

}
