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

    param
    (
        [switch]$Force,
        [switch]$IAgreeToTheEula,
        [switch]$SkipUpdate,
        [int]$DaysToLookBack,
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
        [string]$FolderID = (Get-Date -UFormat %Y%m%d_%H%M).tostring()

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
            Write-Information @(" 
			
	DISCLAIMER:

	THE SAMPLE SCRIPTS ARE NOT SUPPORTED UNDER ANY MICROSOFT STANDARD SUPPORT
	PROGRAM OR SERVICE. THE SAMPLE SCRIPTS ARE PROVIDED AS IS WITHOUT WARRANTY
	OF ANY KIND. MICROSOFT FURTHER DISCLAIMS ALL IMPLIED WARRANTIES INCLUDING, WITHOUT
	LIMITATION, ANY IMPLIED WARRANTIES OF MERCHANTABILITY OR OF FITNESS FOR A PARTICULAR
	PURPOSE. THE ENTIRE RISK ARISING OUT OF THE USE OR PERFORMANCE OF THE SAMPLE SCRIPTS
	AND DOCUMENTATION REMAINS WITH YOU. IN NO EVENT SHALL MICROSOFT, ITS AUTHORS, OR
	ANYONE ELSE INVOLVED IN THE CREATION, PRODUCTION, OR DELIVERY OF THE SCRIPTS BE LIABLE
	FOR ANY DAMAGES WHATSOEVER (INCLUDING, WITHOUT LIMITATION, DAMAGES FOR LOSS OF BUSINESS
	PROFITS, BUSINESS INTERRUPTION, LOSS OF BUSINESS INFORMATION, OR OTHER PECUNIARY LOSS)
	ARISING OUT OF THE USE OF OR INABILITY TO USE THE SAMPLE SCRIPTS OR DOCUMENTATION,
    EVEN IF MICROSOFT HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES
    
    ** THIS MODULE COLLECTS NON-PII INFORMATION TO INFORM THE DEVELOPERS OF ITS USEAGE.
			") 

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

        # Initilize Application Insights client
        $insightkey = "b69ffd8b-4569-497c-8ee7-b71b8257390e"
        if ($Null -eq $Client) {
            Write-Information "Initilizing Application Insights" 
            $Client = New-AIClient -key $insightkey
        }   
    }

 
    ### Main ###
    $InformationPreference = "Continue"

    if (($null -eq (Get-Variable -Name Hawk -ErrorAction SilentlyContinue)) -or ($Force -eq $true) -or ($null -eq $Hawk)) {

        # Setup Applicaiton insights
        New-ApplicationInsight

        # Test if we have a connection to msol
        Test-MSOLConnection

        ### Checking for Updates ###
        # If we are skipping the update log it
        if ($SkipUpdate) {
            Write-Information "Skipping Update Check"
        }
        # Check to see if there is an Update for Hawk
        else {
            Update-HawkModule
        }

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

        ### Setting up Days to Look Back ###
        # Check if our value was passed in
        if ($DaysToLookBack -gt 0) {
            # Validate that the provided information is inside of the acceptable range
            if ((1..365) -notcontains $DaysToLookBack) {
                Write-Error ("Provided value is not inside allowed range" + $DaysToLookBack) -ErrorAction Stop
            }
            # If we are valid then put it into our final value
            else {
                $Days = $DaysToLookBack
            }
        }
        # If not provided then we need to ask
        else {
            Do {
                $Days = Read-Host "How far back in the past should we search? (1-90 Default 90)"
    
                # If nothing is entered default to 90
                if ([string]::IsNullOrEmpty($Days)) { $Days = "90" }
            }
            while
            (
                #Validate that we have a number between 1 and 365 Input claims 90 but some will take >
                (1..365) -notcontains $Days
            )
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
    
        # Null our object then create it
        $Output = $null
        $Output = New-Object -TypeName PSObject

        # Build the output object from what we have collected
        $Output | Add-Member -MemberType NoteProperty -Name FilePath -Value $OutputPath
        $Output | Add-Member -MemberType NoteProperty -Name DaysToLookBack -Value $Days
        $Output | Add-Member -MemberType NoteProperty -Name StartDate -Value (Get-Date ((Get-Date).adddays( - ([int]$Days))) -UFormat %m/%d/%Y)
        $Output | Add-Member -MemberType NoteProperty -Name EndDate -Value (Get-Date ((Get-Date).adddays(1)) -UFormat %m/%d/%Y)
        $Output | Add-Member -MemberType NoteProperty -Name AdvancedAzureLicense -Value $AdvancedAzureLicense
        $Output | Add-Member -MemberType NoteProperty -Name WhenCreated -Value (Get-Date -Format g)
        $Output | Add-Member -MemberType NoteProperty -Name EULA -Value $Eula

        # Create the global hawk variable
        Write-Information "Setting up Global Hawk environment variable`n"
        New-Variable -Name Hawk -Scope Global -value $Output -Force
        Out-LogFile "Global Variable Configured"
        Out-LogFile ("Version " + (Get-Module Hawk).version)
        Out-LogFile $Hawk

        #### End of IF
    }

    else {
        Write-Information "Valid Hawk Object already exists no actions will be taken."
    }
}