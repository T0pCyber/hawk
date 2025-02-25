<#
.SYNOPSIS
    Get the Location of an IP using the ipstack.com REST API
.DESCRIPTION
    Get the Location of an IP using the ipstack.com REST API
.PARAMETER IPAddress
    IP address to look up for geolocation
.PARAMETER AccessKey
    Access key for the API
.EXAMPLE
    Get-IPGeolocation -IPAddress 8.8.8.8 -AccessKey "your_access_key"
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

    begin {}

    process {
        try {
       
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

            # Make API calls to IP Stack to look up IP addresses
            $resource = "http://api.ipstack.com/$($IPAddress)?access_key=$AccessKey"
            $geoip = Invoke-RestMethod -Method Get -URI $resource -ErrorAction Stop
            $geoip | ConvertTo-Json -Depth 10
            
            # Create result object
            $isMSFTIP = Test-MicrosoftIP -IPToTest $geoip.ip -Type $geoip.type
            $result = [PSCustomObject]@{
                IP               = $geoip.ip
                CountryName      = $geoip.country_name
                ContinentName    = $geoip.continent_name
                RegionName       = $geoip.region_name
                RegionCode       = $geoip.region_code
                City             = $geoip.city
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
                RegionName       = "Unknown"
                RegionCode       = "Unknown"
                ContinentName    = "Unknown"
                City             = "Unknown"
                KnownMicrosoftIP = "Unknown"
            }
        }
    }
}