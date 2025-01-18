﻿
<#
.SYNOPSIS
    Get the Location of an IP using the freegeoip.net rest API
.DESCRIPTION
    Get the Location of an IP using the freegeoip.net rest API
.PARAMETER IPAddress
    IP address of geolocation
.EXAMPLE
    Get-IPGeolocation
    Gets all IP Geolocation data of IPs that recieved
.NOTES
    General notes (DCODEV was here <-> If you say so, sir!)
#>
Function Get-IPGeolocation {

    Param
    (
        [Parameter(Mandatory = $true)]
        $IPAddress
    )

    # If we don't have a HawkAppData variable then we need to read it in
    if (!([bool](get-variable HawkAppData -erroraction silentlycontinue))) {
        Read-HawkAppData
    }

    # if there is no value of access_key then we need to get it from the user
    if ($null -eq $HawkAppData.access_key) {

        Out-LogFile "IpStack.com now requires an API access key to gather GeoIP information from their API.`nPlease get a Free access key from https://ipstack.com/ and provide it below." -Information

        # get the access key from the user
        # get the access key from the user
        Out-LogFile "ipstack.com accesskey" -isPrompt -NoNewLine
        $Accesskey = (Read-Host).Trim() 

        # add the access key to the appdata file
        Add-HawkAppData -name access_key -Value $Accesskey
    }
    else {
        $Accesskey = $HawkAppData.access_key
    }

    # Check the global IP cache and see if we already have the IP there
    if ($IPLocationCache.ip -contains $IPAddress) {
        return ($IPLocationCache | Where-Object { $_.ip -eq $IPAddress } )
        Write-Verbose ("IP Cache Hit: " + [string]$IPAddress)
    }
    elseif ($IPAddress -eq "<null>"){
        write-Verbose ("Null IP Provided: " + $IPAddress)
                $hash = @{
                IP               = $IPAddress
                CountryName      = "NULL IP"
                RegionName       = "Unknown"
                RegionCode       = "Unknown"
                ContinentName    = "Unknown"
                City             = "Unknown"
                KnownMicrosoftIP = "Unknown"
            }
    }
    # If not then we need to look it up and populate it into the cache
    else {
        # URI to pull the data from
        $resource = "http://api.ipstack.com/" + $ipaddress + "?access_key=" + $Accesskey

        # Return Data from web
        $Error.Clear()
        $geoip = Invoke-RestMethod -Method Get -URI $resource -ErrorAction SilentlyContinue

        if (($Error.Count -gt 0) -or ($null -eq $geoip.type)) {
            Out-LogFile ("Failed to retreive location for IP " + $IPAddress) -isError
            $hash = @{
                IP               = $IPAddress
                CountryName      = "Failed to Resolve"
                RegionName       = "Unknown"
                RegionCode       = "Unknown"
                ContinentName    = "Unknown"
                City             = "Unknown"
                KnownMicrosoftIP = "Unknown"
            }
        }
        else {
            # Determine if this IP is known to be owned by Microsoft
            [string]$isMSFTIP = Test-MicrosoftIP -IPToTest $IPAddress -type $geoip.type
            if ($isMSFTIP){
                $MSFTIP =  $isMSFTIP
            }
            # Push return into a response object
            $hash = @{
                IP               = $geoip.ip
                CountryName      = $geoip.country_name
                ContinentName    = $geoip.continent_name
                RegionName       = $geoip.region_name
                RegionCode       = $geoip.region_code
                City             = $geoip.City
                KnownMicrosoftIP = $MSFTIP
            }
            $result = New-Object PSObject -Property $hash
        }

        # Push the result to the global IPLocationCache
        [array]$Global:IPlocationCache += $result

        # Return the result to the user
        return $result
    }
}