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
    General notes
#>
function Get-IPGeolocation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$IPAddress,
        
        [Parameter(Mandatory = $false)]
        [string]$AccessKey
    )

    begin {
         
        # If no access key provided, get one
        # You need to test to see if the switch is set
        #if ([string]::IsNullOrEmpty($AccessKey)) {
            # THIS IS NOT WORKING FOR SOME REASON!!!!
            # Get-IPStackAPIKey returns a valid key, but it is not being passed to the function
            # $AccessKey = Get-IPStackAPIKey
        #    $AccessKey = Get-IPStackAPIKey 
        #}
    }

    process {
        try {
            # Handle null IP address

            #$AccessKey = Get-IPStackAPIKey
            #Write-Host "INSIDE GET-IPGEOLOCATION -> RETURNED FROM GET-IPSTACKAPIKEY(): $($AccessKey.GetType()) :: $AccessKey" -ForeGround Yellow
        
            #$AccessKey = 'b084134b5cbb9f1752c47c3ba90be95d'

            if ($IPAddress -eq "<null>") {
                Write-Verbose "Null IP Provided: $IPAddress"
                return [PSCustomObject]@{
                    IP               = $IPAddress
                    CountryName      = "NULL IP"
                    RegionName       = "Unknown"
                    RegionCode       = "Unknown"
                    ContinentName    = "Unknown"
                    City             = "Unknown"
                    KnownMicrosoftIP = "Unknown"
                }
            }

            # Check cache
            if ($Global:IPLocationCache.ip -contains $IPAddress) {
                Write-Verbose "IP Cache Hit: $IPAddress"
                return ($Global:IPLocationCache | Where-Object { $_.ip -eq $IPAddress })
            }

            # Make API call
            #$resource = "http://api.ipstack.com/$IPAddress?access_key=b084134b5cbb9f1752c47c3ba90be95d"
            $resource = "http://api.ipstack.com/$($IPAddress)?access_key=$AccessKey"
            $geoip = Invoke-RestMethod -Method Get -URI $resource -ErrorAction Stop
            #$geoip | ConvertTo-Json -Depth 10 | Out-LogFile "GEOIP: $($geoip.ip) | TYPE: $($geoip.type)" -Information
            $geoip = $geoip | ConvertTo-Json -Depth 10
            #Out-LogFile $geoip -Information

            
            #Out-LogFile "GEOIP: $($geoip.ip) | TYPE: $($geoip.type)" -Information

            # Create result object
            # $isMSFTIP = Test-MicrosoftIP -IPToTest $geoip.ip -type $geoip.type
            $result = [PSCustomObject]@{
                IP               = $geoip.ip
                CountryName      = $geoip.country_name
                ContinentName    = $geoip.continent_name
                RegionName      = $geoip.region_name
                RegionCode      = $geoip.region_code
                City            = $geoip.city
                KnownMicrosoftIP = $isMSFTIP
            }

            # Update cache
            [array]$Global:IPLocationCache += $result

            return $result
        }
        catch {
            Out-LogFile "Failed to retrieve location for IP $IPAddress : $_" -isError
            return [PSCustomObject]@{
                IP               = $IPAddress
                CountryName      = "Failed to Resolve"
                RegionName      = "Unknown"
                RegionCode      = "Unknown"
                ContinentName   = "Unknown"
                City            = "Unknown"
                KnownMicrosoftIP = "Unknown"
            }
        }
    }
}

# Example usage:
# $key = Get-IPStackAPIKey
# Get-IPGeolocation -IPAddress "8.8.8.8" -AccessKey $key

# Or simply:
# Get-IPGeolocation -IPAddress "8.8.8.8"