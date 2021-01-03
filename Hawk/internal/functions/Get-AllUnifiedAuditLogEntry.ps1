<#
.SYNOPSIS
    Make sure we get back all of the unified audit log results for the search we are doing
.DESCRIPTION
    Make sure we get back all of the unified audit log results for the search we are doing
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
Function Get-AllUnifiedAuditLogEntry {
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$UnifiedSearch,
        [datetime]$StartDate = $Hawk.StartDate,
        [datetime]$EndDate = $Hawk.EndDate
    )

    # Validate the incoming search command
    if (($UnifiedSearch -match "-StartDate") -or ($UnifiedSearch -match "-EndDate") -or ($UnifiedSearch -match "-SessionCommand") -or ($UnifiedSearch -match "-ResultSize") -or ($UnifiedSearch -match "-SessionId")) {
        Out-LogFile "Do not include any of the following in the Search Command"
        Out-LogFile "-StartDate, -EndDate, -SessionCommand, -ResultSize, -SessionID"
        Write-Error -Message "Unable to process search command, switch in UnifiedSearch that is handled by this cmdlet specified" -ErrorAction Stop
    }

    # Make sure key variables are null
    [string]$cmd = $null

    # build our search command to execute
    $cmd = $UnifiedSearch + " -StartDate `'" + (get-date ($StartDate) -UFormat %m/%d/%Y) + "`' -EndDate `'" + (get-date ($endDate) -UFormat %m/%d/%Y) + "`' -SessionCommand ReturnLargeSet -resultsize 5000 -sessionid " + (Get-Date -UFormat %H%M%S)
    Out-LogFile ("Running Unified Audit Log Search")
    Out-Logfile $cmd

    # Run the initial command
    $Output = $null
    # $Output = New-Object System.Collections.ArrayList

    # Setup our run variable
    $Run = $true

    # Since we have more than 1k results we need to keep returning results until we have them all
    while ($Run) {
        $Output += (Invoke-Expression $cmd)

        # Check for null results if so warn and stop
        if ($null -eq $Output) {
            Out-LogFile ("[WARNING] - Unified Audit log returned no results.")
            $Run = $false
        }
        # Else continue
        else {
            # Sort our result set to make sure the higest number is in the last position
            $Output = $Output | Sort-Object -Property ResultIndex

            # if total result count returned is 0 then we should warn and stop
            if ($Output[-1].ResultCount -eq 0) {
                Out-LogFile ("[WARNING] - Returned Result count was 0")
                $Run = $false
            }
            # if our resultindex = our resultcount then we have everything and should stop
            elseif ($Output[-1].Resultindex -ge $Output[-1].ResultCount) {
                Out-LogFile ("Retrieved all results.")
                $Run = $false
            }

            # Output the current progress
            Out-LogFile ("Retrieved:" + $Output[-1].ResultIndex.tostring().PadRight(5, " ") + " Total: " + $Output[-1].ResultCount)
        }
    }

    # Convert our list to an array and return it
    [array]$Output = $Output
    return $Output
}