<#
.SYNOPSIS
    Get-IPStackAPIKey is called by Get-HawkUserUALSignInLog to ensure a valid API key is available for use with ipstack.com.
    Once a valid key is provided, it is saved and used by Get-IPGeolocation to resolve IP addresses to geolocation data.
.DESCRIPTION
    Validate REST API key from ipstack.com
.PARAMETER None
    No parameters
.EXAMPLE
    [string]$AccessKey = Get-IPStackAPIKey
.NOTES
    Get-IPStackAPIKey also uses Test-GeoIPAPIKey to validate the API key.
#>
function Get-IPStackAPIKey {
    [CmdletBinding()]
    param()

    begin {
        [string]$newKey = $null
        [string]$AccessKeyFromFile = $null
    }

    process {

        try {
            # Read in existing HawkAppData
            if (!([bool](Get-Variable HawkAppData -ErrorAction SilentlyContinue))) {
                Read-HawkAppData
                if ($HawkAppData.access_key) {
                    Out-LogFile "HawkAppData JSON file read successfully." -Information
                    [string]$AccessKeyFromFile = $HawkAppData.access_key
                }
                else {
                    Out-LogFile "HawkAppData Access Key is null/empty." -Information
                }
            }

            # Check for existing access key on disk
            if (-not [string]::IsNullOrEmpty($AccessKeyFromFile)){
                do {
                    $maskedKey = "**************************" + $AccessKeyFromFile.Substring($AccessKeyFromFile.Length - 6)
                    Out-LogFile "Found existing API key ending in: $maskedKey" -Information
                    Out-LogFile "Would you like to use this existing key? (Y/N): " -isPrompt -NoNewLine
                    $useExistingKey = (Read-Host).Trim().ToUpper()
            
                    if ($useExistingKey -notin @('Y','N')) {
                        Out-LogFile "Please enter Y or N" -Information
                    } else {
                        if ($useExistingKey -eq 'Y') {
                            # Test existing key
                            Out-LogFile "Validating existing API key: $maskedKey" -Information
                            if (Test-GeoIPAPIKey -Key $AccessKeyFromFile) {
                                Out-LogFile "API KEY VALIDATED :: Using existing API key from disk -> $maskedKey" -Information
                                return $AccessKeyFromFile
                            }else {
                                # If access key on file is invalid, set access key to null and prompt for new key
                                Out-LogFile "API KEY `"$maskedKey`" INVALID :: Prompt user for new API key" -Information
                                $AccessKeyFromFile = $null
                            }
                        } elseif ($useExistingKey -eq 'N') {
                            $AccessKeyFromFile = $null
                            Out-LogFile "Existing API key Unkown or Disabled -> Prompt for user provided API key." -Information
                        }
                    }
                } while ($useExistingKey -notin @('Y','N'))
            } 

            # If no existing access key is found on disk, prompt for a new one
            if ([string]::IsNullOrEmpty($AccessKeyFromFile)) {
                # Display informational messages once before looping
                Out-LogFile "IpStack.com requires an API access key to gather GeoIP information." -Information
                Out-LogFile "Get your free API key at: https://ipstack.com/" -Information
            
                # Loop until a valid key is provided
                do {
                    # Prompt user for the API key
                    Out-LogFile "Please provide your IP Stack API key: " -isPrompt -NoNewLine
                    $newKey = (Read-Host).Trim()
            
                    # Ensure user input provided for API key is not null or empty before testing the API key for validity
                    if ([string]::IsNullOrEmpty($newKey)) {
                        Out-LogFile "Failed to update IP Stack API key: Cannot bind argument to parameter 'Key' because it is an empty string." -isError
                        $isValid = $false
                    }else {
                        Out-LogFile "Validating API key: $newKey" -Information
                        $isValid = Test-GeoIPAPIKey -Key $newKey
                    }
                    
                    # If invalid, inform the user and loop again
                    if (-not $isValid) {
                        Out-LogFile "Invalid API key. Please try again." -Action
                    }
                } while (-not $isValid)
            
                # Once a valid key is entered, prompt to save it
                Out-LogFile "Would you like to save your API key to disk? (Y/N): " -isPrompt -NoNewLine
                $saveChoice = ''
                while ($saveChoice -notin @('Y','N')) {
                    $saveChoice = (Read-Host).Trim().ToUpper()

                    if ($GeoIPResponse -notin @('Y','N')) {
                        Out-LogFile "Please enter Y or N for your response: " -isPrompt -NoNewLine
                    }
            
                    if ($saveChoice -eq 'Y') {
                        # Save the ipstack REST API key to HawkAppData
                        Add-HawkAppData -name access_key -Value $newKey
                        $appDataPath = Join-Path $env:LOCALAPPDATA "Hawk\Hawk.json"
                        Out-LogFile "WARNING: Your API key has been saved to: $appDataPath" -Action
                        Out-LogFile "WARNING: Your API key is stored in plaintext." -Information
                        break
                    }
                    if ($GeoIPResponse -eq 'N') {
                        Out-LogFile "REST API Key for ipstack.com is not saved to disk." -Information
                        break
                    }
                }

                # Return the validated key
                return $newKey
            }
        }
        catch {
            Out-LogFile $_.Exception.Message -isError
            throw "$($_.Exception.Message)"
        }
    }
}