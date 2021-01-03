<#
.SYNOPSIS
    Writes output to a log file with a time date stamp
.DESCRIPTION
    Writes output to a log file with a time date stamp
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
Function Out-LogFile {
    Param
    (
        [string]$string,
        [switch]$action,
        [switch]$notice,
        [switch]$silentnotice
	)
	
	Write-PSFMessage -Message $string -ModuleName Hawk -FunctionName (Get-PSCallstack)[1].FunctionName

    # Make sure we have the Hawk Global Object
    if ([string]::IsNullOrEmpty($Hawk.FilePath)) {
        Initialize-HawkGlobalObject
    }

    # Get our log file path
    $LogFile = Join-path $Hawk.FilePath "Hawk.log"
    $ScreenOutput = $true
    $LogOutput = $true

    # Get the current date
    [string]$date = Get-Date -Format G

    # Deal with each switch and what log string it should put out and if any special output

    # Action indicates that we are starting to do something
    if ($action) {
        [string]$logstring = ( "[" + $date + "] - [ACTION] - " + $string)

    }
    # If notice is true the we should write this to intersting.txt as well
    elseif ($notice) {
        [string]$logstring = ( "[" + $date + "] - ## INVESTIGATE ## - " + $string)

        # Build the file name for Investigate stuff log
        [string]$InvestigateFile = Join-Path (Split-Path $LogFile -Parent) "_Investigate.txt"
        $logstring | Out-File -FilePath $InvestigateFile -Append
    }
    # For silent we need to supress the screen output
    elseif ($silentnotice) {
        [string]$logstring = ( "Addtional Information: " + $string)
        # Build the file name for Investigate stuff log
        [string]$InvestigateFile = Join-Path (Split-Path $LogFile -Parent) "_Investigate.txt"
        $logstring | Out-File -FilePath $InvestigateFile -Append

        # Supress screen and normal log output
        $ScreenOutput = $false
        $LogOutput = $false

    }
    # Normal output
    else {
        [string]$logstring = ( "[" + $date + "] - " + $string)
    }

    # Write everything to our log file
    if ($LogOutput) {
        $logstring | Out-File -FilePath $LogFile -Append
    }

    # Output to the screen
    if ($ScreenOutput) {
        Write-Information -MessageData $logstring -InformationAction Continue
    }

}