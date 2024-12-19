Function Out-LogFile {
    <#
    .SYNOPSIS
        Writes output to a log file with a time date stamp.
    .DESCRIPTION
        Writes output to a log file with a time date stamp and appropriate prefixes
        based on the type of message (action, notice, etc.). By default, messages are
        also displayed on the screen unless the -NoDisplay switch is used.

    .PARAMETER string
        The log message to be written.

    .PARAMETER action
        Switch indicating the log entry is describing an action being performed.

    .PARAMETER notice
        Switch indicating the log entry requires investigation or special attention.

    .PARAMETER silentnotice
        Switch indicating additional investigative information that should not be
        displayed on the screen. This is logged to the file but suppressed in console output.

    .PARAMETER NoDisplay
        Switch indicating the message should only be written to the log file,
        not displayed in the console.

    .EXAMPLE
        Out-LogFile "Routine scan completed."

        Writes a simple log message with a timestamp to the log file and displays it on the screen.

    .EXAMPLE
        Out-LogFile "Starting mailbox export operation" -action

        Writes a log message indicating an action is being performed. 
        The output is prefixed with [ACTION] in the log file.

    .EXAMPLE
        Out-LogFile "Detected suspicious login attempt from external IP" -notice

        Writes a log message indicating a situation requiring investigation. 
        The output is prefixed with [INVESTIGATE] and also recorded in a separate _Investigate.txt file.

    .EXAMPLE
        Out-LogFile "User mailbox configuration details" -silentnotice

        Writes investigative detail to the log and _Investigate.txt file without printing to the console. 
        This is useful for adding detail to a previously logged [INVESTIGATE] event without cluttering the console.

    .EXAMPLE
        Out-LogFile "Executing periodic health check" -NoDisplay

        Writes a log message to the file without displaying it on the console, 
        useful for routine logging that doesn't need immediate user visibility.
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