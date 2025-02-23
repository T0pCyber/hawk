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
function Get-IPStackAPIKey {
    [CmdletBinding()]
    param()

    try {
        # Read in existing HawkAppData
        if (!([bool](Get-Variable HawkAppData -ErrorAction SilentlyContinue))) {
            Read-HawkAppData
            [string]$AccessKeyFromFile = $HawkAppData.access_key
        }

        #$IsValidAPIKey = $false

        # Check for existing key
        if (-not [string]::IsNullOrEmpty($AccessKeyFromFile)) {
            $maskedKey = "**************************" + $AccessKeyFromFile.Substring($AccessKeyFromFile.Length - 6)
            Out-LogFile "Found existing API key ending in: $maskedKey" -Information
            Out-LogFile "Would you like to use this existing key? (Y/N): " -isPrompt -NoNewLine
            $useExistingKey = (Read-Host).Trim().ToUpper()

            if ($useExistingKey -eq 'Y') {
                # Test existing key
                if (Test-GeoIPAPIKey -Key $AccessKeyFromFile) {
                    Out-LogFile "Using existing API key from disk." -Information
                    return $AccessKeyFromFile
                }
                else {
                    $AccessKeyFromFile = $null
                    Out-LogFile "Existing API key validation failed." -isError
                    return $AccessKeyFromFile
                }
                
            }
        }

        if (-not [string]::IsNullOrEmpty($AccessKeyFromFile)) {
            
            # Get new key from user
            Out-LogFile "IpStack.com requires an API access key to gather GeoIP information." -Information
            Out-LogFile "Get your free API key at: https://ipstack.com/" -Information
            Out-LogFile "Please provide your IP Stack API key: " -isPrompt -NoNewLine
            $newKey = (Read-Host).Trim()

            #if ([string]::IsNullOrEmpty($newKey)) {
            #    throw "Cannot use empty API key"
            #}

            # Validate new key
            if (-not (Test-GeoIPAPIKey -Key $newKey)) {
                throw "API key validation failed"
            }

            # Prompt to save new key
            Out-LogFile "Would you like to save your API key to disk? (Y/N): " -isPrompt -NoNewLine
            $saveChoice = (Read-Host).Trim().ToUpper()

            if ($saveChoice -eq 'Y') {
                Add-HawkAppData -name access_key -Value $newKey
                $appDataPath = Join-Path $env:LOCALAPPDATA "Hawk\Hawk.json"
                Out-LogFile "WARNING: Your API key has been saved to: $appDataPath" -Action
                Out-LogFile "NOTE: The API key is stored in plaintext format" -Information
            }

            return $newKey
        }
    }
    catch {
        Out-LogFile $_.Exception.Message -isError
        throw "$($_.Exception.Message)"
    }
}

function Get-IPGeolocation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$IPAddress,
        
        [Parameter()]
        [string]$AccessKey
    )

    begin {
        # If no access key provided, get one
        if ([string]::IsNullOrEmpty($AccessKey)) {
            $AccessKey = Get-IPStackAPIKey
        }
    }

    process {
        try {
            # Handle null IP address
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
            $resource = "http://api.ipstack.com/$IPAddress?access_key=$AccessKey"
            $geoip = Invoke-RestMethod -Method Get -URI $resource -ErrorAction Stop

            # Create result object
            $isMSFTIP = Test-MicrosoftIP -IPToTest $IPAddress -type $geoip.type
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