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
            [string]$AccessKeyOnFile = $HawkAppData.access_key
        }
    }

    process {
        try {
            # If there is no value of access_key then we need to get it from the user
            if ([string]::IsNullOrEmpty($AccessKeyFromFile)) {
                Out-LogFile "IpStack.com now requires an API access key to gather GeoIP information from their API." -Information
                Out-LogFile "Please get a Free access key from https://ipstack.com/ and provide it below." -Information
                Out-LogFile "Get your free API key at: https://ipstack.com/" -Information
    
                # Get the access key from the user
                Out-LogFile "Provide your IP Stack API key: " -isPrompt -NoNewLine
                $AccessKey = (Read-Host).Trim()
    
                # Check for empty string or null entered by the user
                if ([string]::IsNullOrEmpty($AccessKey)) {
                    Out-LogFile "Failed to update IP Stack API key: Cannot bind argument to parameter 'Key' because it is an empty string." -isError
                    return
                }
    
                # Only test the key if it's not empty
                $IsValidAccessKey = Test-GeoIPAPIKey -Key $AccessKey
                if (-not $IsValidAccessKey) {
                    Out-LogFile "API key validation failed" -isError
                    return
                }
            }
            # Handle existing key from file
            elseif (-not [string]::IsNullOrEmpty($AccessKeyFromFile)) {
                try {
                    if (Test-GeoIPAPIKey -Key $AccessKeyFromFile) {
                        $AccessKey = $AccessKeyFromFile
                        $IsValidAccessKey = $true
                    }
                }
                catch {
                    Out-LogFile "API key is malformed!" -isError
                    throw "API key validation failed: $($response.error.info)"
                }
            }
        }
        catch {
            Out-LogFile "An unexpected error occurred: $_" -isError
            throw
        }

        # Validate key format (basic check)
        #if ([string]::IsNullOrWhiteSpace($AccessKey)) {
        #    Out-LogFile "API key cannot be empty or whitespace." -isError
        #    throw "API key cannot be empty or whitespace."
        #}

        # Geo IP location is requested, validate the key first (using Google DNS).
        if ($IsValidAccessKey) {
            Out-LogFile "Testing API key against Google DNS..." -Action 
            $testUrl = "http://api.ipstack.com/8.8.8.8?access_key=$AccessKey"
            
            try {
                $response = Invoke-RestMethod -Uri $testUrl -Method Get
                if ($response.success -eq $false) {
                    Out-LogFile "API key validation failed: $($response.error.info)" -isError
                    return "API key validation failed: $($response.error.info)"
                }
                Out-LogFile "API key validated successfully!" -Information

                # Save to disk (C:\Users\%USERPROFILE%\AppData\Local\Hawk\Hawk.json)
                # PROMPT USER TO SEE IF THEY WANT TO WRITE API KEY TO DISK (PLAINTEXT)
                # The ipstack API key is valid. Add the access key to the appdata file
                # Prompt user about saving the API key
                Out-LogFile "Would you like to save your API key to disk? (Y/N): " -isPrompt -NoNewLine
                $saveChoice = (Read-Host).Trim().ToUpper()

                if ($saveChoice -eq 'Y') {
                    # Save to disk
                    Add-HawkAppData -name access_key -Value $AccessKey

                    # Display warning banner about storage location
                    $appDataPath = Join-Path $env:LOCALAPPDATA "Hawk\Hawk.json"
                    Out-LogFile "`nWARNING: Your API key has been saved to: $appDataPath" -Action
                    Out-LogFile "NOTE: The API key is stored in plaintext format" -Information
                    return
                }
                else {
                    Out-LogFile "API key will not be saved to disk." -Information
                    return
                }
                #Add-HawkAppData -name access_key -Value $AccessKey
                #Out-HawkAppData
            }
            catch {
                Out-LogFile "API key validation failed: $_" -isError
                throw "API key validation failed: $_"

            }
        }
            
            #else {
                # API Key is already exists from the appdata file (Hawk\Hawk.json)
            #    $AccessKey = $HawkAppData.access_key
            #}
        #}
        #catch {
        #    Out-LogFile "Failed to update IP Stack API key: $_" -isError
        #    throw "Failed to update IP Stack API key: $_"
        #}
    


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