Function Initialize-HawkGlobalObject {
    <#
.SYNOPSIS
    Create global variable $Hawk for use by all Hawk cmdlets.
.DESCRIPTION
    Creates the global variable $Hawk and populates it with information needed by the other Hawk cmdlets.

    * Checks for latest version of the Hawk module
    * Creates path for output files
    * Records target start and end dates for searches
.PARAMETER Force
    Switch to force the function to run and allow the variable to be recreated
.PARAMETER SkipUpdate
    Skips checking for the latest version of the Hawk Module
.PARAMETER DaysToLookBack
    Defines the # of days to look back in the availible logs.
    Valid values are 1-90
.PARAMETER StartDate
    First day that data will be retrieved
.PARAMETER EndDate
    Last day that data will be retrieved
.PARAMETER FilePath
    Provide an output file path.
.OUTPUTS
    Creates the $Hawk global variable and populates it with a custom PS object with the following properties

    Property Name	Contents
    ==========		==========
    FilePath		Path to output files
    DaysToLookBack	Number of day back in time we are searching
    StartDate		Calculated start date for searches based on DaysToLookBack
    EndDate			One day in the future
    WhenCreated		Date and time that the variable was created
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

        # Create a folder ID based on date
        [string]$TenantName = (Get-MGDomain | Where-Object { $_.isDefault }).ID
        [string]$FolderID = "Hawk_" + $TenantName.Substring(0, $TenantName.IndexOf('.')) + "_" + (Get-Date -UFormat %Y%m%d_%H%M).tostring()

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

        # We need to ask for start and end date if daystolookback was not set
        if ($null -eq $StartDate) {

            # Read in our # of days back or the actual start date
            $StartRead = Read-Host "`nPlease Enter First Day of Search Window (1-90, Date, Default 90)"

            # Determine if the input was a date time
            # True means it was NOT a datetime
            if ($Null -eq ($StartRead -as [DateTime])) {
                #### Not a Date time ####

                # if we have a null entry (just hit enter) then set startread to the default of 90
                if ([string]::IsNullOrEmpty($StartRead)) { $StartRead = 90 }
                elseif (($StartRead -gt 90) -or ($StartRead -lt 1)) {
                    Write-Information "Value provided is outside of valid Range 1-90"
                    Write-Information "Setting StartDate to default of Today - 90 days"
                    $StartRead = 90
                }

                # Calculate our startdate setting it to midnight
                [DateTime]$StartDate = ((Get-Date).AddDays(-$StartRead)).Date
                Write-Information ("Start Date: " + $StartDate + "")
            }
            elseif (!($null -eq ($StartRead -as [DateTime]))) {
                #### DATE TIME Provided ####

                # Convert the input to a date time object
                [DateTime]$StartDate = (Get-Date $StartRead).Date

                # Test to make sure the date time is > 90 and < today
                if ($StartDate -ge ((Get-date).AddDays(-90).Date) -and ($StartDate -le (Get-Date).Date)) {
                    #Valid Date do nothing
                }
                else {
                    Write-Information ("Date provided beyond acceptable range of 90 days.")
                    Write-Information ("Setting date to default of Today - 90 days.")
                    [DateTime]$StartDate = ((Get-Date).AddDays(-90)).Date
                }
            }
            else {
                Write-Error "Invalid date information provided.  Could not determine if this was a date or an integer." -ErrorAction Stop
            }
        }

        if ($null -eq $EndDate) {
            # Read in the end date
            $EndRead = Read-Host "`nPlease Enter Last Day of Search Window (1-90, date, Default Today)"

            # Determine if the input was a date time
            # True means it was NOT a datetime
            if ($Null -eq ($EndRead -as [DateTime])) {
                #### Not a Date time ####

                # if we have a null entry (just hit enter) then set startread to the default of 90
                if ([string]::IsNullOrEmpty($EndRead)) {
                    [DateTime]$EndDate = ((Get-Date).AddDays(1)).Date
                }
                else {
                    # Calculate our startdate setting it to midnight
                    Write-Information ("End Date: " + $EndRead + " days.")
                    # Subtract 1 from the EndRead entry so that we get one day less for the purpose of how searching works with times
                    [DateTime]$EndDate = ((Get-Date).AddDays( - ($EndRead - 1))).Date
                }

                # Validate that the start date is further back in time than the end date
                if ($StartDate -gt $EndDate) {
                    Write-Error "StartDate Cannot be More Recent than EndDate" -ErrorAction Stop
                }
                else {
                    Write-Information ("End Date: " + $EndDate + "`n")
                }
            }
            elseif (!($null -eq ($EndRead -as [DateTime]))) {
                #### DATE TIME Provided ####

                # Convert the input to a date time object
                [DateTime]$EndDate = ((Get-Date $EndRead).AddDays(1)).Date

                # Test to make sure the end date is newer than the start date
                if ($StartDate -gt $EndDate) {
                    Write-Information "EndDate Selected was older than start date."
                    Write-Information "Setting EndDate to today."
                    [DateTime]$EndDate = ((Get-Date).AddDays(1)).Date
                }
                elseif ($EndDate -gt (get-Date).AddDays(2)) {
                    Write-Information "EndDate to Far in the furture."
                    Write-Information "Setting EndDate to Today."
                    [DateTime]$EndDate = ((Get-Date).AddDays(1)).Date
                }

                Write-Information ("Setting EndDate by Date to " + $EndDate + "`n")
            }

            else {
                Write-Error "Invalid date information provided.  Could not determine if this was a date or an integer." -ErrorAction Stop
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
            FilePath = $OutputPath
            DaysToLookBack = $Days
            StartDate = $StartDate
            EndDate = $EndDate
            WhenCreated = (Get-Date -Format g)
            MaxAuditDays = (Test-HawkLicenseType) 
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
            }
            else {
                $prop.Value
            }
        
            Out-LogFile ("{0} = {1}" -f $prop.Name, $value) -Information
        }
        #### End of IF
    }

    else {
        Write-Information "Valid Hawk Object already exists no actions will be taken."
    }
}