Function Out-LogFile {
    <#
    .SYNOPSIS
        Writes output to a log file with a time date stamp
    .DESCRIPTION
        Writes output to a log file with a time date stamp and appropriate prefixes
        based on the type of message (action, notice, etc.)
    .PARAMETER string
        Log Message
    .PARAMETER action
        Switch indicating an action is being performed
    .PARAMETER notice
        Switch indicating this is a notice that requires investigation
    .PARAMETER silentnotice
        Switch indicating this is additional information for an investigation notice
    .PARAMETER NoDisplay
        Switch indicating the message should only be written to the log file, not displayed
    #>
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory = $true)]
        [string]$string,
        [switch]$action,
        [switch]$notice,
        [switch]$silentnotice,
        [switch]$NoDisplay
    )

    Write-PSFMessage -Message $string -ModuleName Hawk -FunctionName (Get-PSCallstack)[1].FunctionName

    # Make sure we have the Hawk Global Object
    if ([string]::IsNullOrEmpty($Hawk.FilePath)) {
        Initialize-HawkGlobalObject
    }

    # Get our log file path
    $LogFile = Join-path $Hawk.FilePath "Hawk.log"
    $ScreenOutput = -not $NoDisplay
    $LogOutput = $true

    # Get the current date
    [string]$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    [string]$logstring = ""

    # Build the log string based on the type of message
    if ($action) {
        $logstring = "[$timestamp] - [ACTION] - $string"
    }
    elseif ($notice) {
        $logstring = "[$timestamp] - [INVESTIGATE] - $string"

        # Write to the investigation file
        [string]$InvestigateFile = Join-Path (Split-Path $LogFile -Parent) "_Investigate.txt"
        $logstring | Out-File -FilePath $InvestigateFile -Append
    }
    elseif ($silentnotice) {
        $logstring = "[$timestamp] - [INVESTIGATE] - Additional Information: $string"

        # Write to the investigation file
        [string]$InvestigateFile = Join-Path (Split-Path $LogFile -Parent) "_Investigate.txt"
        $logstring | Out-File -FilePath $InvestigateFile -Append

        # Suppress regular output for silentnotice
        $ScreenOutput = $false
        $LogOutput = $false
    }
    else {
        $logstring = "[$timestamp] - $string"
    }

    # Write to log file if enabled
    if ($LogOutput) {
        $logstring | Out-File -FilePath $LogFile -Append
    }

    # Write to screen if enabled
    if ($ScreenOutput) {
        Write-Information -MessageData $logstring -InformationAction Continue
    }
}