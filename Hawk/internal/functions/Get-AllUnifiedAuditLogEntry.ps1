﻿Function Get-AllUnifiedAuditLogEntry {
    <#
    .SYNOPSIS
        Make sure we get back all of the unified audit log results for the search we are doing
    .DESCRIPTION
        Make sure we get back all of the unified audit log results for the search we are doing
    .PARAMETER UnifiedSearch
        The search parameters
    .PARAMETER StartDate
        The start date provided by user during Hawk Object Initialization
    .PARAMETER EndDate
        The end date provide by the user during Hawk Object Initialization
    .EXAMPLE
        Get-AllUnifiedAuditLogEntry
        Gets all unified auditlog entries
    .NOTES
        General notes
    #>
        param (
            [Parameter(Mandatory = $true)]
            [string]$UnifiedSearch,
            [datetime]$StartDate = $Hawk.StartDate,
            [datetime]$EndDate = $Hawk.EndDate
        )

        # Validate the incoming search command
        if ($UnifiedSearch -match "-StartDate|-EndDate|-SessionCommand|-ResultSize|-SessionId") {
            Out-LogFile "Do not include any of the following in the Search Command" -isError
            Out-LogFile "-StartDate, -EndDate, -SessionCommand, -ResultSize, -SessionID" -isError
            Write-Error -Message "Unable to process search command, switch in UnifiedSearch that is handled by this cmdlet specified" -ErrorAction Stop
        }

        # build our search command to execute
        $cmd = $UnifiedSearch + " -StartDate `'" + (get-date ($StartDate) -UFormat %m/%d/%Y) + "`' -EndDate `'" + (get-date ($endDate) -UFormat %m/%d/%Y) + "`' -SessionCommand ReturnLargeSet -resultsize 5000 -sessionid " + (Get-Date -UFormat %H%M%S)
        Out-LogFile ("Running Unified Audit Log Search") -Action
        Out-Logfile $cmd -NoDisplay
    
        # Run the initial command
        $Output = $null
        # $Output = New-Object System.Collections.ArrayList
    
        # Setup our run variable
        $Run = $true
    
        # Convert the command string into a scriptblock to avoid Invoke-Expression
        $searchScript = [ScriptBlock]::Create($cmd)
    
        # Since we have more than 1k results we need to keep returning results until we have them all
        while ($Run) {
            $Output += & $searchScript
    
            # Check for null results if so warn and stop
            if ($null -eq $Output) {
                Out-LogFile ("Unified Audit log returned no results.") -Information
                $Run = $false
            }
            # Else continue
            else {
                # Sort our result set to make sure the higest number is in the last position
                $Output = $Output | Sort-Object -Property ResultIndex
    
                # if total result count returned is 0 then we should warn and stop
                if ($Output[-1].ResultCount -eq 0) {
                    Out-LogFile ("Returned Result count was 0") -Information
                    $Run = $false
                }
                # if our resultindex = our resultcount then we have everything and should stop
                elseif ($Output[-1].Resultindex -ge $Output[-1].ResultCount) {
                    Out-LogFile ("Retrieved all results.") -Information
                    $Run = $false
                }
    
                # Output the current progress
                Out-LogFile ("Retrieved:" + $Output[-1].ResultIndex.tostring().PadRight(5, " ") + " Total: " + $Output[-1].ResultCount) -Information
            }
        }
    
        # Convert our list to an array and return it
        [array]$Output = $Output
        return $Output
    }