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
Function Get-IPGeolocation {

    Param
    (
        [Parameter(Mandatory = $true)]
        $IPAddress
    )

    begin {
        # Read in existing HawkAppData
        if (!([bool](Get-Variable HawkAppData -ErrorAction SilentlyContinue))) {
            Read-HawkAppData
        }
    }

    process {
        try {
            # if there is no value of access_key then we need to get it from the user
            if ([string]::IsNullOrEmpty($HawkAppData.access_key)) {

                Out-LogFile "IpStack.com now requires an API access key to gather GeoIP information from their API.`nPlease get a Free access key from https://ipstack.com/ and provide it below." -Information

                Out-LogFile "`nIP Stack API Key Configuration" -Action
                Out-LogFile "Get your free API key at: https://ipstack.com/`n" -Action

                # get the access key from the user
                Out-LogFile "ipstack.com accesskey " -isPrompt -NoNewLine
                $AccessKey = (Read-Host "Enter your IP Stack API key").Trim() 

                # Validate key format (basic check)
                if ([string]::IsNullOrWhiteSpace($AccessKey)) {
                    Out-LogFile "API key cannot be empty or whitespace." -isError
                    throw | Out-Null
                }

                # If testing is requested, validate the key
                if ($AccessKey) {
                    Out-LogFile "Testing API key against Google DNS..." -Action 
                    $testUrl = "http://api.ipstack.com/8.8.8.8?access_key=$AccessKey"
                    
                    try {
                        $response = Invoke-RestMethod -Uri $testUrl -Method Get
                        if ($response.success -eq $false) {
                            Out-LogFile "API key validation failed: $($response.error.info)" -isError
                            throw | Out-Null
                        }
                        Out-LogFile "API key validated successfully!" -Information

                        # Save to disk
                        Out-HawkAppData
                    }
                    catch {
                        Out-LogFile "API key validation failed: $_" -isError
                        throw | Out-Null

                    }
                }

                # The ipstack API key is valid. Add the access key to the appdata file
                Add-HawkAppData -name access_key -Value $AccessKey
            }
            else {
                $AccessKey = $HawkAppData.access_key
            }
        }
        catch {
            Out-LogFile "Failed to update IP Stack API key: $_" -isError
            throw | Out-Null
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
            $resource = "http://api.ipstack.com/" + $ipaddress + "?access_key=" + $AccessKey

            # Return Data from web
            $Error.Clear()
            $geoip = Invoke-RestMethod -Method Get -URI $resource -ErrorAction SilentlyContinue

            if (($Error.Count) -or ([string]::IsNullOrEmpty($geoip.type))) {
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
                    $MSFTIP = $isMSFTIP
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
}