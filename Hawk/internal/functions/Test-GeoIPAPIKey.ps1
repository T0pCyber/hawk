Function Test-GeoIPAPIKey {
    <#
    .SYNOPSIS
        Validates the supplied API key for ipstack.com.
    .DESCRIPTION
        Checks if the provided API key is valid by performing format checks and making a request to ipstack.com,
        using Google's DNS (8.8.8.8) for domain resolution. Returns a boolean indicating the key's validity.
    .PARAMETER Key
        The API key to validate. Must be a 32-character hexadecimal string.
    .OUTPUTS
        Boolean: $true if the API key is valid, $false otherwise.
    .EXAMPLE
        Test-GeoIPAPIKey -Key "your32characterhexkeyhere"
        Tests whether the provided key is valid for use with ipstack.com.
    #>
    param (
        [Parameter(Mandatory)]
        [string]$Key
    )

    process {
        # Check for null or empty string
        if ([string]::IsNullOrEmpty($Key)) {
            Out-LogFile "Failed to update IP Stack API key: Cannot bind argument to parameter 'Key' because it is an empty string." -isError
            return $false
        }

        # Verify the key is exactly 32 characters
        if ($Key.Length -ne 32) {
            Out-LogFile "API key length is not 32 characters." -isError
            return $false
        }

        # Check if the key contains only hexadecimal characters (0-9, a-f)
        if (-not ($Key -match '^[0-9a-f]{32}$')) {
            Out-LogFile "API key contains invalid characters. Must be hexadecimal (0-9, a-f)." -isError
            return $false
        }

        # Resolve api.ipstack.com using Google's DNS (8.8.8.8)
        try {
            $dnsResult = Resolve-DnsName -Name api.ipstack.com -Server 8.8.8.8 -Type A -ErrorAction Stop
            if ($null -eq $dnsResult -or $dnsResult.Count -eq 0) {
                Out-LogFile "No IP addresses resolved for api.ipstack.com using Google's DNS." -isError
                return $false
            }
            # Take the first IPv4 address
            $ip = $dnsResult.IPAddress | Select-Object -First 1
        }
        catch {
            Out-LogFile "Failed to resolve api.ipstack.com using Google's DNS: $_" -isError
            return $false
        }

        # Construct the API request URI using the resolved IP and the API key
        $uri = "http://$ip/check?access_key=$Key"
        $headers = @{ "Host" = "api.ipstack.com" }

        # Make the API request
        try {
            $response = Invoke-WebRequest -Uri $uri -Headers $headers -Method Get -ErrorAction Stop
        }
        catch {
            Out-LogFile "Failed to contact ipstack API: $_" -isError
            return $false
        }

        # Verify the response status code is 200 OK
        if ($response.StatusCode -ne 200) {
            Out-LogFile "ipstack API returned status code $($response.StatusCode), expected 200." -isError
            return $false
        }

        # Parse the JSON response
        try {
            $content = $response.Content | ConvertFrom-Json
        }
        catch {
            Out-LogFile "Failed to parse ipstack API response: $_" -isError
            return $false
        }

        # Check the response for validity
        # ipstack returns "success": false with an "error" object for invalid keys
        if ($content.success -eq $false) {
            Out-LogFile "API key validation failed: $($content.error.info)" -isError
            return $false
        }
        else {
            # Successful responses lack "success" (it's null) and contain data like "ip"
            Out-LogFile "Test-GeoIPAPIKey: API Key validated successfully."
            return $true
        }
    }
}