<#
.SYNOPSIS
    Sleeps X seconds and displays a progress bar
.DESCRIPTION
    Sleeps X seconds and displays a progress bar
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
Function Start-SleepWithProgress {
    Param([int]$sleeptime)

    # Loop Number of seconds you want to sleep
    For ($i = 0; $i -le $sleeptime; $i++) {
        $timeleft = ($sleeptime - $i);

        # Progress bar showing progress of the sleep
        Write-Progress -Activity "Sleeping" -CurrentOperation "$Timeleft More Seconds" -PercentComplete (($i / $sleeptime) * 100);

        # Sleep 1 second
        start-sleep 1
    }

    Write-Progress -Completed -Activity "Sleeping"
}