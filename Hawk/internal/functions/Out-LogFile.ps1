Function Out-LogFile {
    <#
    .SYNOPSIS
        Writes output to a log file with a time date stamp.

    .DESCRIPTION
        Writes output to a log file with a time date stamp and appropriate prefixes
        based on the type of message. By default, messages are also displayed on the screen 
        unless the -NoDisplay switch is used.

        Message types:
        - Action: Represent ongoing operations or procedures.
        - Error: Represent failures, exceptions, or error conditions that prevented successful execution. 
        - Investigate (notice, silentnotice): Represent events that require attention or hold 
        investigative value.
        - Information: Represent successful completion or informational status updates
        that do not require action or investigation.
        - Warning: Indicates warning conditions that need attention but aren't errors.
        - Prompt: Indicates user input is being requested.

    .PARAMETER string
        The log message to be written.

    .PARAMETER action
        Switch indicating the log entry is describing an action being performed.

    .PARAMETER isError
        Switch indicating the log entry represents an error condition or failure.
        The output is prefixed with [ERROR] in the log file.

    .PARAMETER notice
        Switch indicating the log entry requires investigation or special attention.

    .PARAMETER silentnotice
        Switch indicating additional investigative information that should not be
        displayed on the screen. This is logged to the file but suppressed in console output.

    .PARAMETER NoDisplay
        Switch indicating the message should only be written to the log file,
        not displayed in the console.

    .PARAMETER Information
        Switch indicating the log entry provides informational status or completion messages,
        for example: "Retrieved all results" or "Completed data export successfully."

    .PARAMETER isWarning
        Switch indicating the log entry is a warning message.
        The output is prefixed with [WARNING] in the log file.

    .PARAMETER isPrompt 
        Switch indicating the log entry is a user prompt message.
        The output is prefixed with [PROMPT] in the log file.

    .PARAMETER NoNewLine
        Switch indicating the message should be written without a newline at the end,
        useful for prompts where input should appear on the same line.

    .EXAMPLE
        Out-LogFile "Routine scan completed."

        Writes a simple log message with a UTC timestamp to the log file and displays it on the screen.

    .EXAMPLE
        Out-LogFile "Starting mailbox export operation" -action

        Writes a log message indicating an action is being performed. 
        The output is prefixed with [ACTION] in the log file.

    .EXAMPLE
        Out-LogFile "Failed to connect to Exchange Online" -isError

        Writes a log message indicating an error condition.
        The output is prefixed with [ERROR] in the log file.

    .EXAMPLE
        Out-LogFile "Enter your selection: " -isPrompt -NoNewLine

        Writes a prompt message without a newline so user input appears on the same line.
        The output is prefixed with [PROMPT] in the log file.

    .EXAMPLE
        Out-LogFile "Detected suspicious login attempt from external IP" -notice

        Writes a log message indicating a situation requiring investigation. 
        The output is prefixed with [INVESTIGATE] and also recorded in a separate _Investigate.txt file.

    .EXAMPLE
        Out-LogFile "User mailbox configuration details" -silentnotice

        Writes investigative detail to the log and _Investigate.txt file without printing to the console. 
        This is useful for adding detail to a previously logged [INVESTIGATE] event without cluttering the console.

    .EXAMPLE
        Out-LogFile "Retrieved all results successfully" -Information

        Writes a log message indicating a successful or informational event. 
        The output is prefixed with [INFO], suitable for status updates or completion notices.
            
    .EXAMPLE
        Out-LogFile "System resource warning: High CPU usage" -isWarning

        Writes a warning message to indicate a concerning but non-critical condition.
        The output is prefixed with [WARNING] in the log file.

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
        [switch]$isError,
        [switch]$NoDisplay,
        [switch]$Information,
        [switch]$isWarning,
        [switch]$isPrompt,
        [switch]$NoNewLine
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

    # Get the current date in UTC
    [string]$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd HH:mm:ss UTC")
    [string]$logstring = ""

    # Build the log string based on the type of message
    if ($action) {
        $logstring = "[$timestamp] [-] - $string"
    }
    elseif ($isError) {
        $logstring = "[$timestamp] [!] - ERROR: $string"
    }
    elseif ($notice) {
        $logstring = "[$timestamp] [*] - INVESTIGATE: $string"

        # Write to the investigation file
        [string]$InvestigateFile = Join-Path (Split-Path $LogFile -Parent) "_Investigate.txt"
        $logstring | Out-File -FilePath $InvestigateFile -Append
    }
    elseif ($silentnotice) {
        $logstring = "[$timestamp] [*] - Additional Information: $string"

        # Write to the investigation file
        [string]$InvestigateFile = Join-Path (Split-Path $LogFile -Parent) "_Investigate.txt"
        $logstring | Out-File -FilePath $InvestigateFile -Append

        # Suppress regular output for silentnotice
        $ScreenOutput = $false
        $LogOutput = $false
    }
    elseif ($Information) {
        $logstring = "[$timestamp] [+] - $string"
    }
    elseif ($isWarning) {
        $logstring = "[$timestamp] [-] - WARNING: $string"
    }
    elseif ($isPrompt) {
        $logstring = "[$timestamp] [>] - $string"
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
        if ($NoNewLine) {
            Write-Host $logstring -InformationAction Continue -NoNewLine
        }
        else {
            Write-Information $logstring -InformationAction Continue
        }
    }
}