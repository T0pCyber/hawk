# TODO: Filter out successful logons and report those seperate from full list
# With that possibily include a "expected region" to do more filtering?
# Maybe a seperate function for that?
Function Get-HawkUserAuthHistory {
    param
    (
        [Parameter(Mandatory = $true)]
        [array]$UserPrincipalName,
        [switch]$ResolveIPLocations
    )

    Test-EXOConnection

    # Verify our UPN input
    [array]$UserArray = Test-UserObject -ToTest $UserPrincipalName

    foreach ($Object in $UserArray) {
        [string]$User = $Object.UserPrincipalName

        # Make sure our array is null
        [array]$UserLogonLogs = $null

        Out-LogFile ("Retrieving Logon History for " + $User) -action

        # Get back the account logon logs for the user
        $UserLogonLogs = Get-AllUnifiedAuditLogEntry -UnifiedSearch ("Search-UnifiedAuditLog -ObjectIds " + $User + " -RecordType AzureActiveDirectoryAccountLogon")

        # Expand out the AuditData and convert from JSON
        $ExpandedUserLogonLogs = $UserLogonLogs | Select-object -ExpandProperty AuditData | ConvertFrom-Json

        # Get only the unique IP addresses and report them
        [array]$LogonIPs = $ExpandedUserLogonLogs | Select-Object -Unique -Property ClientIP
        Out-LogFile ("Found " + $LogonIPs.count + " Unique IPs attempting to connect to this user")
        $LogonIPs | Out-MultipleFileType -fileprefix "All_Attempted_Logon_IPAddresses" -User $user -csv

        # Make sure we have some logons before we process them
        if ($null -eq $LogonIPs) {
            Out-LogFile ("No logons found")
        }
        # If we do then process the logon objects further
        else {

            # Set our Output array to null
            [array]$Output = $Null

            # if we have the resolve ip locations switch then we need to resolve the ip address to the location
            if ($ResolveIPLocations) {

                # Make sure our arrays are null
                [array]$IPLocations = $null
                $i = 0
                $EstimatedLookupTime = [int]($LogonIPs.Count * 1.5)

                # Loop thru each connection and get the location
                Foreach ($connection in $ExpandedUserLogonLogs) {

                    Write-Progress -Activity "Looking Up Ip Address Locations" -CurrentOperation $connection.ClientIP -PercentComplete (($i / $ExpandedUserLogonLogs.count) * 100) -Status ("Approximate Max Run time " + $EstimatedLookupTime + " seconds")

                    # Get the location information for this IP address
                    $Location = Get-IPGeolocation -ipaddress $connection.clientip

                    # Add all of the locations for this user to an array of locations
                    [array]$IPLocations += $Location

                    # Combine the connection object and the location object so that we have a single output ready
                    $Output += $connection | Select-Object -Property *, @{Name = "CountryName"; Expression = {$Location.CountryName}}, @{Name = "RegionCode"; Expression = {$Location.RegionCode}}, @{Name = "RegionName"; Expression = {$Location.RegionName}}, @{Name = "City"; Expression = {$Location.City}}, @{Name = "ZipCode"; Expression = {$Location.ZipCode}}, @{Name = "KnownMicrosoftIP"; Expression = {$Location.KnownMicrosoftIP}}

                    # increment our counter for the progress bar
                    $i++

                }

                Write-Progress -Completed -Activity "Looking Up Ip Address Locations" -Status " "

                Out-LogFile "Writing All Attempted Logon sessions with IP Locations"
                $Output | Out-MultipleFileType -fileprefix "Attempted_Logon_Events_With_Locations" -User $User -csv -xml
                
                # Pull out successful logons because they are more interesting
                [array]$SuccessfulLogons = $Output | Where-Object {$_.ResultStatus -eq 'Succeeded'} 
                
                # Null check successfullogons and return a defult value
                if ($null -eq $SuccessfulLogons)
                {
                    [PSCustomObject]@{Warning = "No Success Logons found. This could point towards a problem gathering data or an issue with the filter that is used by Hawk.  Please review the RAW data"} | Out-MultipleFileType -FilePrefix "Successful_Logon_Events_With_Locations" -User $User -csv -xml
                }
                else 
                {
                    $SuccessfulLogons | Out-MultipleFileType -FilePrefix "Successful_Logon_Events_With_Locations" -User $User -csv -xml
                }

                

                Out-LogFile "Writing List of unique logon locations"
                Select-UniqueObject -ObjectArray $IPLocations -Property ip | Out-MultipleFileType -fileprefix "Attempted_Logon_Locations" -user $user -csv -txt
                $Global:IPlocationCache | Out-MultipleFileType -FilePrefix "All_Attempted_Logon_Locations" -csv
            }

            # if we don't have the lookup ip address switch then ouput just = our existing data
            else {
                
                $Output = $ExpandedUserLogonLogs
                Out-LogFile "Writing Logon Session"
                $Output | Out-MultipleFileType -fileprefix "Attempted_Logon_Events" -User $user -csv -xml
                
                # Pull out successful logons because they are more interesting
                [array]$SuccessfulLogons = $Output | Where-Object {$_.ResultStatus -eq 'Succeeded'} 

                # Null check successfullogons and return a defult value
                if ($null -eq $SuccessfulLogons)
                {
                    [PSCustomObject]@{Warning = "No Success Logons found. This could point towards a problem gathering data or an issue with the filter that is used by Hawk.  Please review the RAW data"} | Out-MultipleFileType -FilePrefix "Successful_Logon_Events_With_Locations" -User $User -csv -xml
                }
                else 
                {
                    $SuccessfulLogons | Out-MultipleFileType -FilePrefix "Successful_Logon_Events" -User $User -csv -xml
                }
            }
        }
    }

    <#

	.SYNOPSIS
	Gathers ip addresses that logged onto the user account

	.DESCRIPTION
	Pulls AzureActiveDirectoryAccountLogon events from the unified audit log for the provided user.

    If used with -ResolveIPLocations:
	Attempts to resolve the IP location using freegeoip.net
	Will flag ip addresses that are known to be owned by Microsoft using the XML from:
	https://support.office.com/en-us/article/URLs-and-IP-address-ranges-for-Office-365-operated-by-21Vianet-5C47C07D-F9B6-4B78-A329-BFDC1B6DA7A0

	.PARAMETER UserPrincipalName
	Single UPN of a user, commans seperated list of UPNs, or array of objects that contain UPNs.

	.OUTPUTS

    File: Logon_IPAddresses.csv
	Path: \<User>
	Description: All unique logon IP addresses for this user.

	File: Logon_IPAddresses.txt
	Path: \<User>
	Description: All unique logon IP addresses for this user.

	File: Logon_IPAddresses.txt
	Path: \<User>
	Description: All unique logon IP addresses for this user.

	==== If -ResolveIPLocations is specified. ====

	File: Attempted_Logon_Events_With_Locations.csv
	Path: \<User>
	Description: List of all logon events with the location discovered for the IP and if it is a Microsoft IP.

	File: Attempted_Logon_Events_With_Locations.xml
	Path: \<User>\XML
	Description: List of all logon events with the location discovered for the IP and if it is a Microsoft IP in CLI XML.

	File: Successful_Logon_Events_With_Locations.csv
	Path: \<User>
	Description: List of all logon events that had ResultStatus = Succeeded. Includes the location discovered for the IP and if it is a Microsoft IP.

	File: Successful_Logon_Events_With_Locations.xml
	Path: \<User>\XML
	Description: List of all logon events that had ResultStatus = Succeeded. Includes the location discovered for the IP and if it is a Microsoft IP in CLI XML.

	File: All_Attempted_Logon_Locations.csv
	Path: \
	Description: All ip addresses and their resolved locations for ALL users investigated.

	==== If -ResolveIPLocations is NOT specified. ====

	File: Attempted_Logon_Events.csv
	Path: \<User>
	Description:  All logon events that were found.

	File: Attempted_Logon_Events.xml
	Path: \<User>\XML
	Description: All logon events that were found in CLI XML.

	File: Successful_Logon_Events.csv
	Path: \<User>
	Description:  All logon events that had LoginStatus = 0.

	File: Successful_Logon_Events.xml
	Path: \<User>\XML
	Description: All logon events that had LoginStatus = 0 in CLI XML.

	
	.EXAMPLE

	Get-HawkUserAuthHistory -UserPrincipalName user@contoso.com -ResolveIPLocations

	Gathers authenication information for user@contoso.com.
	Attempts to resolve the IP locations for all authetnication IPs found.

	.EXAMPLE

	Get-HawkUserAuthHistory -UserPrincipalName (get-mailbox -Filter {Customattribute1 -eq "C-level"}) -ResolveIPLocations

	Gathers authenication information for all users that have "C-Level" set in CustomAttribute1
	Attempts to resolve the IP locations for all authetnication IPs found.
	
	#>	
}