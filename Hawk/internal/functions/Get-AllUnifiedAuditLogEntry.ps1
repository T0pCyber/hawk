Function Get-AllUnifiedAuditLogEntry {
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
        Out-LogFile ("Running Unified Audit Log Search (" + (get-date ($StartDate) -UFormat %m/%d/%Y) + " to " + (get-date ($endDate) -UFormat %m/%d/%Y) + ")")
        Out-Logfile $cmd
    
     
        $Output = $null
        # $Output = New-Object System.Collections.ArrayList
    
        try {
            # Run the initial command
            $Output += Invoke-UnifiedAuditLogSearch -cmd $cmd
        }
        catch [System.Management.Automation.PSInvalidOperationException] {
            Out-LogFile ("[ERROR] $_")
			Out-LogFile ("Let's try to get the data ​​for each day. It may take a while")
            $Daily = $true
            $Output = $null
        }
    
        # IF the InvokeY-UnifiedAuditLogSearch-UnifiedAuditLogSearch result is > 50000, split daily
        if ($Daily) {
    
            # Check if the dates are 1 day or less different
            $DifferenceDate = ($EndDate - $StartDate).Days

            if ($DifferenceDate -le 1) {
    
                Out-LogFile ("Running Unified Audit Log Search (" + (get-date ($StartDate) -UFormat %m/%d/%Y) + " to " + (get-date ($endDate) -UFormat %m/%d/%Y) + ")")
                Out-Logfile $cmd
                Out-Logfile("[ERROR] The distance between dates is less than 1 day and the number of results is more than 50000. Consider retrieving values manually.")
            }
            else {
                # Loop through dates
                $Count = 1
                for ([datetime]$Date = $StartDate; $Date -lt $EndDate; $Date = $Date.AddDays(1)) {
                    [datetime]$NextDate = $Date.AddDays(1)
                    $cmd = $UnifiedSearch + " -StartDate `'$Date`' -EndDate `'$NextDate`' -SessionCommand ReturnLargeSet -resultsize 5000 -sessionid " + (Get-Date -UFormat %H%M%S) + $Count
                    Out-LogFile ("Running Unified Audit Log Search (" + (get-date ($Date) -UFormat %m/%d/%Y) + " to " + (get-date ($NextDate) -UFormat %m/%d/%Y) + ")")
                    Out-Logfile $cmd
                    $Output += Invoke-UnifiedAuditLogSearch -cmd $cmd
                    $count += 1
                }
            }
        }
    
        # Convert our list to an array and return it
        [array]$Output = $Output
        return $Output
    }
    
    Function Invoke-UnifiedAuditLogSearch {
        [CmdletBinding()]
        param (
            [Parameter()]
            [string] $cmd
        )
    
        # Run the initial command
        $Output = $null
    
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
                # Verification if its > 50000 total result, if its yes, throw an exception
                elseif (50000 -lt $Output[-1].ResultCount){
                    throw [System.Management.Automation.PSInvalidOperationException]::new("ResultCount(Total: " + $Output[-1].ResultCount + ") is either greater than or equal to 50000.")
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
        return $Output
    }