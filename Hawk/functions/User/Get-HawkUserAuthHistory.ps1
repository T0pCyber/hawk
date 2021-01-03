Function Get-HawkUserAuthHistory {
    <#

	.SYNOPSIS
	Gathers ip addresses that logged into the user account

	.DESCRIPTION
	Pulls AzureActiveDirectoryAccountLogon events from the unified audit log for the provided user.

    If used with -ResolveIPLocations:
	Attempts to resolve the IP location using freegeoip.net
	Will flag ip addresses that are known to be owned by Microsoft using the XML from:
	https://support.office.com/en-us/article/URLs-and-IP-address-ranges-for-Office-365-operated-by-21Vianet-5C47C07D-F9B6-4B78-A329-BFDC1B6DA7A0

	.PARAMETER UserPrincipalName
	Single UPN of a user, comma seperated list of UPNs, or array of objects that contain UPNs.

	.OUTPUTS

    File: Converted_Authentication_Logs.csv
	Path: \<User>
	Description: All authentication activity for the user in a more readable form
    	
	.EXAMPLE

	Get-HawkUserAuthHistory -UserPrincipalName user@contoso.com -ResolveIPLocations

	Gathers authentication information for user@contoso.com.
	Attempts to resolve the IP locations for all authentication IPs found.

	.EXAMPLE

	Get-HawkUserAuthHistory -UserPrincipalName (get-mailbox -Filter {Customattribute1 -eq "C-level"}) -ResolveIPLocations

	Gathers authentication information for all users that have "C-Level" set in CustomAttribute1
	Attempts to resolve the IP locations for all authentication IPs found.
	
	#>	
    param
    (
        [Parameter(Mandatory = $true)]
        [array]$UserPrincipalName,
        [switch]$ResolveIPLocations
    )

    Test-EXOConnection
    Send-AIEvent -Event "CmdRun"

    # Verify our UPN input
    [array]$UserArray = Test-UserObject -ToTest $UserPrincipalName
    [array]$RecordTypes = "AzureActiveDirectoryAccountLogon", "AzureActiveDirectory", "AzureActiveDirectoryStsLogon"

    foreach ($Object in $UserArray) {
        
        [string]$User = $Object.UserPrincipalName

        # Make sure our array is null
        [array]$UserLogonLogs = $null

        Out-LogFile ("Retrieving Logon History for " + $User) -action

        # Get back the account logon logs for the user
        foreach ($Type in $RecordTypes) {
            Out-LogFile ("Searching Unified Audit log for Records of type: " + $Type)
            $UserLogonLogs += Get-AllUnifiedAuditLogEntry -UnifiedSearch ("Search-UnifiedAuditLog -UserIds " + $User + " -RecordType " + $Type)    
        }

        # Make sure we have results
        if ($null -eq $UserLogonLogs) {
            Out-LogFile "[ERROR] - No results found when searching UAL for AzureActiveDirectoryAccountLogon events"
        }
        else {
            	
            # Expand out the AuditData and convert from JSON
            Out-LogFile "Converting AuditData"
            $ExpandedUserLogonLogs = $null
            $ExpandedUserLogonLogs = New-Object System.Collections.ArrayList
            $FailedConversions = $null
            $FailedConversions = New-Object System.Collections.ArrayList

            # Process our results in a way to deal with JSON Errors
            Foreach ($Entry in $UserLogonLogs){

                try {
                    $jsonEntry = $Entry.AuditData | ConvertFrom-Json
                    $ExpandedUserLogonLogs.Add($jsonEntry) | Out-Null
                }
                catch {
                    $FailedConversions.Add($Entry) | Out-Null
                }
            }

            if ($FailedConversions -le 0){}
            else {
                Out-LogFile ("[ERROR] - " + $FailedConversions.Count + " Entries failed JSON Conversion")
                $FailedConversions | Out-MultipleFileType -fileprefix "Failed_Conversion_Authentication_Logs" -user $User -csv
            }

            # Add IP Geo Location information to the data
            if ($ResolveIPLocations) {
                # Setup our counter
                $i = 0

                # Loop thru each connection and get the location
                while ($i -lt $ExpandedUserLogonLogs.Count) {

                    if ([bool]($i % 25)) { }
                    Else {
                        Write-Progress -Activity "Looking Up Ip Address Locations" -CurrentOperation $i -PercentComplete (($i / $ExpandedUserLogonLogs.count) * 100)
                    }
                    

                    # Get the location information for this IP address
                    $Location = Get-IPGeolocation -ipaddress $ExpandedUserLogonLogs.item($i).clientip
                    
                    # Combine the connection object and the location object so that we have a single output ready
                    $ExpandedUserLogonLogs.item($i) = ($ExpandedUserLogonLogs.item($i) | Select-Object -Property *, @{Name = "CountryName"; Expression = { $Location.CountryName } }, @{Name = "RegionCode"; Expression = { $Location.RegionCode } }, @{Name = "RegionName"; Expression = { $Location.RegionName } }, @{Name = "City"; Expression = { $Location.City } }, @{Name = "ZipCode"; Expression = { $Location.ZipCode } }, @{Name = "KnownMicrosoftIP"; Expression = { $Location.KnownMicrosoftIP } })

                    # increment our counter for the progress bar
                    $i++
                }

                Write-Progress -Completed -Activity "Looking Up Ip Address Locations" -Status " "   
            }
            else {
                Out-LogFile "ResolveIPLocations not specified"
            }

            # Convert to human readable and export
            Out-LogFile "Converting to Human Readable"
            (Import-AzureAuthenticationLogs -JsonConvertedLogs $ExpandedUserLogonLogs) | Out-MultipleFileType -fileprefix "Converted_Authentication_Logs" -User $User -csv

            # Export RAW data
            $UserLogonLogs | Out-MultipleFileType -fileprefix "Raw_Authentication_Logs" -user $User -csv

        }
    }


}
