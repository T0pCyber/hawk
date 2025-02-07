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
            [string]$AccessKeyFromFile = $HawkAppData.access_key
        }
    }

    process {
        try {
            # If there is no access_key on disk (file) then we need to get it from the user
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
    
                # Test the existing key
                $IsExistingValidAccessKey = Test-GeoIPAPIKey -Key $AccessKey
                if (-not $IsExistingValidAccessKey) {
                    Out-LogFile "API key validation failed" -isError
                    return
                }
            }
            # Handle existing key from file
            elseif (-not [string]::IsNullOrEmpty($AccessKeyFromFile)) {
                try {
                    # Get last 6 characters of the API key
                    $maskedKey = "**************************" + $AccessKeyFromFile.Substring($AccessKeyFromFile.Length - 6)
                    
                    # Prompt user about using existing key
                    Out-LogFile "Found existing API key ending in: $maskedKey" -Information
                    Out-LogFile "Would you like to use this existing key? (Y/N): " -isPrompt -NoNewLine
                    $useExistingKey = (Read-Host).Trim().ToUpper()

                    if ($useExistingKey -eq 'Y') {
                        if (Test-GeoIPAPIKey -Key $AccessKeyFromFile) {
                            # Set the API access key from the file to $AccessKey, which is used to test against IP Stack API.
                            $AccessKey = $AccessKeyFromFile

                            # This is to ensure the user doesn't get prompted to save a key that is already on disk
                            $IsExistingValidAccessKey = $true
                            Out-LogFile "Using existing API key from disk." -Information
                            break # USE RETURN OR BREAK!!!!
                        }
                        
                    }
                    else {
                        # No access key was obtained from the file on disk
                        # This is to ensure the user doesn't get prompted to save a key that is already on disk
                        $IsExistingValidAccessKey = $false
                        Out-LogFile "Please provide a new IP Stack API key: " -isPrompt -NoNewLine
                        $AccessKey = (Read-Host).Trim()
                        
                        # Check for empty string or null entered by the user
                        if ([string]::IsNullOrEmpty($AccessKey)) {
                            Out-LogFile "Failed to update IP Stack API key: Cannot bind argument to parameter 'Key' because it is an empty string." -isError
                            return
                        }

                        # Test the new key
                        $IsValidUserEnteredAccessKey = Test-GeoIPAPIKey -Key $AccessKey
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
            throw "An unexpected error occurred: $_"
        }

        # Validate key format (basic check)
        #if ([string]::IsNullOrWhiteSpace($AccessKey)) {
        #    Out-LogFile "API key cannot be empty or whitespace." -isError
        #    throw "API key cannot be empty or whitespace."
        #}

        # Geo IP location is requested, validate the key first (using Google DNS).
        if ($IsValidUserEnteredAccessKey -or $IsExistingValidAccessKey) {
            Out-LogFile "Testing API key against Google DNS..." -Action 
            $testUrl = "http://api.ipstack.com/8.8.8.8?access_key=$AccessKey"
            
            try {
                $response = Invoke-RestMethod -Uri $testUrl -Method Get
                if ($response.success -eq $false) {
                    Out-LogFile "API key validation failed: $($response.error.info)" -isError
                    throw "API key validation failed: $($response.error.info)"
                }
                Out-LogFile "API key validated successfully!" -Information

                # Save to disk (C:\Users\%USERPROFILE%\AppData\Local\Hawk\Hawk.json)
                # PROMPT USER TO SEE IF THEY WANT TO WRITE API KEY TO DISK (PLAINTEXT)
                # No key is on disk or was omitted AND the user entered a proper functioning IP Stack API access key
                if (!$IsExistingValidAccessKey -and $IsValidUserEnteredAccessKey) {
                    Out-LogFile "Would you like to save your API key to disk? (Y/N): " -isPrompt -NoNewLine
                    $saveChoice = (Read-Host).Trim().ToUpper()

                    if ($saveChoice -eq 'Y') {
                        # Save to disk
                        Add-HawkAppData -name access_key -Value $AccessKey

                        # Display warning banner about storage location
                        $appDataPath = Join-Path $env:LOCALAPPDATA "Hawk\Hawk.json"
                        Out-LogFile "`nWARNING: Your API key has been saved to: $appDataPath" -Action
                        Out-LogFile "NOTE: The API key is stored in plaintext format" -Information
                        break
                    }
                    else {
                        Out-LogFile "API key will not be saved to disk." -Information
                        break
                    }
                }
                break # TRYING TO PREVENT THE PROMPT OF IP STACK API KEY FROM LOOPING!
            }
            catch {
                Out-LogFile "API key validation failed: $_" -isError
                #throw "API key validation failed: $_"
                return
            }
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
        return
    }
}