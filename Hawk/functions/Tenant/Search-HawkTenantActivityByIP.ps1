# Searches the unified audit log for logon activity by IP address
Function Search-HawkTenantActivityByIP {
    param
    (
        [parameter(Mandatory = $true)]
        [string]$IpAddress
    )

    Test-EXOConnection
    Send-AIEvent -Event "CmdRun"

    # Replace an : in the IP address with . since : isn't allowed in a directory name
    $DirectoryName = $IpAddress.replace(":", ".")

    # Make sure we got only a single IP address
    if ($IpAddress -like "*,*") {
        Out-LogFile "Please provide a single IP address to search."
        Write-Error -Message "Please provide a single IP address to search." -ErrorAction Stop
    }	

    Out-LogFile ("Searching for events related to " + $IpAddress) -action

    # Gather all of the events related to these IP addresses
    [array]$ipevents = Get-AllUnifiedAuditLogEntry -UnifiedSearch ("Search-UnifiedAuditLog -IPAddresses " + $IPAddress )

    # If we didn't get anything back log it
    if ($null -eq $ipevents) {
        Out-LogFile ("No IP logon events found for IP "	+ $IpAddress)
    }

    # If we did then process it
    else {

        # Expand out the Data and convert from JSON
        [array]$ipeventsexpanded = $ipevents | Select-object -ExpandProperty AuditData | ConvertFrom-Json
        Out-LogFile ("Found " + $ipeventsexpanded.count + " related to provided IP" )
        $ipeventsexpanded | Out-MultipleFileType -FilePrefix "All_Events" -csv -User $DirectoryName

        # Get the logon events that were a success
        [array]$successipevents = $ipeventsexpanded | Where-Object { $_.ResultStatus -eq "success" }
        Out-LogFile ("Found " + $successipevents.Count + " Successful logons related to provided IP")
        $successipevents | Out-MultipleFileType -FilePrefix "Success_Events" -csv -User $DirectoryName

        # Select all unique users accessed by this IP
        [array]$uniqueuserlogons = Select-UniqueObject -ObjectArray $ipeventsexpanded -Property "UserID"
        Out-LogFile ("IP " + $ipaddress + " has tried to access " + $uniqueuserlogons.count + " users") -notice
        $uniqueuserlogons | Out-MultipleFileType -FilePrefix "Unique_Users_Attempted" -csv -User $DirectoryName -Notice

        if ($null -eq $uniqueuserlogonssuccess) {
            Out-LogFile ("No Successful Logon Events found for this IP: " + $IpAddress)
        }
        else {
            [array]$uniqueuserlogonssuccess = Select-UniqueObject -ObjectArray $successipevents -Property "UserID"
            Out-LogFile ("IP " + $IpAddress + " SUCCESSFULLY accessed " + $uniqueuserlogonssuccess.count + " users") -notice
            $uniqueuserlogonssuccess | Out-MultipleFileType -FilePrefix "Unique_Users_Success" -csv -User $DirectoryName -Notice
        }
	
    }	

    <#
 
	.SYNOPSIS
	Gathers logon activity based on a submitted IP Address.

	.DESCRIPTION
	Pulls logon activity from the Unified Audit log based on a provided IP address.
	Processes the data to highlight successful logons and the number of users accessed by a given IP address.

	.OUTPUTS
	
	File: All_Events.csv
	Path: \<IP>
	Description: All logon events

	File: All_Events.xml
	Path: \<IP>\xml
	Description: Client XML of all logon events

	File: Success_Events.csv
	Path: \<IP>
	Description: All logon events that were successful

	File: Unique_Users_Attempted.csv
	Path: \<IP>
	Description: List of Unique users that this IP tried to log into

	File: Unique_Users_Success.csv
	Path: \<IP>
	Description: Unique Users that this IP succesfully logged into

	File: Unique_Users_Success.xml
	Path: \<IP>\XML
	Description: Client XML of unique users the IP logged into

	
	.EXAMPLE

	Search-HawkTenantActivityByIP -IPAddress 10.234.20.12

	Searches for all Logon activity from IP 10.234.20.12.
	
	#>

}