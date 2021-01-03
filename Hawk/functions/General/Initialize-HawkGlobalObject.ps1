# Create the hawk global object for use by other cmdlets in the hawk module
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

    .PARAMETER IAgreeToTheEula
    Agrees to the EULA on the command line to skip the prompt.

    .PARAMETER SkipUpdate
    Skips checking for the latest version of the Hawk Module

    .PARAMETER DaysToLookBack
    Defines the # of days to look back in the availible logs.
    Valid values are 1-90

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
	EULA			If you have agreed to the EULA or not

	.EXAMPLE
	Initialize-HawkGlobalObject -Force

    This Command will force the creation of a new $Hawk variable even if one already exists.

    #>
	[CmdletBinding()]
    param
    (
        [switch]$Force,
        [switch]$IAgreeToTheEula,
        [switch]$SkipUpdate,
        [int]$DaysToLookBack,
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
        param([string]$RootPath)

        # Create a folder ID based on date
        [string]$FolderID = "Hawk_" + (Get-Date -UFormat %Y%m%d_%H%M).tostring()

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

    Function Get-Eula {

        if ([string]::IsNullOrEmpty($Hawk.EULA)) {
            Write-Information ('

	DISCLAIMER:

	Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
			')

            # Prompt the user to agree with EULA
            $title = "Disclaimer"
            $message = "Do you agree with the above disclaimer?"
            $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Logs agreement and continues use of the Hawk Functions."
            $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Stops execution of Hawk Functions"
            $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
            $result = $host.ui.PromptForChoice($title, $message, $options, 0)
            # If yes log and continue
            # If no log error and exit
            switch ($result) {
                0 {
                    Write-Information "`n"
                    Return ("Agreed " + (Get-Date)).ToString()
                }
                1 {
                    Write-Information "Aborting Cmdlet"
                    Write-Error -Message "Failure to agree with EULA" -ErrorAction Stop
                    break
                }
            }
        }
        else { Return $Hawk.EULA }

    }

    Function New-ApplicationInsight {

        # Initialize Application Insights client
        $insightkey = "b69ffd8b-4569-497c-8ee7-b71b8257390e"
        if ($Null -eq $Client) {
            Write-Information "Initializing Application Insights"
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

        # Test if we have a connection to msol
        Test-MSOLConnection

        # If the global variable Hawk doesn't exist or we have -force then set the variable up
        Write-Information "Setting Up initial Hawk environment variable"

        ### Validating EULA ###
        if ($IAgreeToTheEula) {
            # Customer has accepted the EULA on the command line
            [string]$Eula = ("Agreed " + (Get-Date))
        }
        else {
            [string]$Eula = Get-Eula
        }

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
            $StartRead = Read-Host "`nFirst Day of Search Window (1-90, Date, Default 90)"

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
                Write-Information ("Calculating Start Date from current date minus " + $StartRead + " days.")
                [DateTime]$StartDate = ((Get-Date).AddDays(-$StartRead)).Date
                Write-Information ("Setting StartDate by Calculation to " + $StartDate + "`n")
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

                Write-Information ("Setting StartDate by Date to " + $StartDate + "`n")
            }
            else {
                Write-Error "Invalid date information provided.  Could not determine if this was a date or an integer." -ErrorAction Stop
            }
        }

        if ($null -eq $EndDate) {
            # Read in the end date
            $EndRead = Read-Host "`nLast Day of search Window (1-90, date, Default Today)"

            # Determine if the input was a date time
            # True means it was NOT a datetime
            if ($Null -eq ($EndRead -as [DateTime])) {
                #### Not a Date time ####

                # if we have a null entry (just hit enter) then set startread to the default of 90
                if ([string]::IsNullOrEmpty($EndRead)) {
                    Write-Information ("Setting End Date to Today")
                    [DateTime]$EndDate = ((Get-Date).AddDays(1)).Date
                }
                else {
                    # Calculate our startdate setting it to midnight
                    Write-Information ("Calculating End Date from current date minus " + $EndRead + " days.")
                    # Subtract 1 from the EndRead entry so that we get one day less for the purpose of how searching works with times
                    [DateTime]$EndDate = ((Get-Date).AddDays( - ($EndRead - 1))).Date
                }

                # Validate that the start date is further back in time than the end date
                if ($StartDate -gt $EndDate) {
                    Write-Error "StartDate Cannot be More Recent than EndDate" -ErrorAction Stop
                }
                else {
                    Write-Information ("Setting EndDate by Calculation to " + $EndDate + "`n")
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
                elseif ($EndDate -gt (get-Date).AddDays(2)){
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


        # Determine if we have access to a P1 or P2 Azure Ad License
        # EMS SKU contains Azure P1 as part of the sku
        if ([bool](Get-MsolAccountSku | Where-Object { ($_.accountskuid -like "*aad_premium*") -or ($_.accountskuid -like "*EMS*") })) {
            Write-Information "Advanced Azure AD License Found"
            [bool]$AdvancedAzureLicense = $true
        }
        else {
            Write-Information "Advanced Azure AD License NOT Found"
            [bool]$AdvancedAzureLicense = $false
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
			AdvancedAzureLicense = $AdvancedAzureLicense
			WhenCreated = (Get-Date -Format g)
			EULA = $Eula
		}

        # Create the script hawk variable
        Write-Information "Setting up Script Hawk environment variable`n"
        New-Variable -Name Hawk -Scope Script -value $Output -Force
        Out-LogFile "Script Variable Configured"
        Out-LogFile ("*** Version " + (Get-Module Hawk).version + " ***")
        Out-LogFile $Hawk

        #### End of IF
    }

    else {
        Write-Information "Valid Hawk Object already exists no actions will be taken."
    }
}
