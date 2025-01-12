Function Get-HawkTenantAppAndSPNCredentialDetail {
    <#
    .SYNOPSIS
        Tenant Azure Active Directory Applications and Service Principal Credential details export using Microsoft Graph.
    .DESCRIPTION
        Tenant Azure Active Directory Applications and Service Principal Credential details export. Credential details can be used to
        review when credentials were created for an Application or Service Principal. If a malicious user created a certificate or password
        used to access corporate data, then knowing the key creation time will be instrumental to determining the time frame of when an attacker
        had access to data.
    .EXAMPLE
        Get-HawkTenantAppAndSPNCredentialDetail
        Gets all Tenant Application and Service Principal Details
    .OUTPUTS
        SPNCertsAndSecrets.csv
        ApplicationCertsAndSecrets
    .LINK
        https://learn.microsoft.com/en-us/graph/api/serviceprincipal-list
        https://learn.microsoft.com/en-us/graph/api/application-list
    .NOTES
        Updated to use Microsoft Graph API instead of AzureAD module
    #>
    [CmdletBinding()]
    param()

    BEGIN {
        # Check if Hawk object exists and is fully initialized
        if (Test-HawkGlobalObject) {
            Initialize-HawkGlobalObject
        }

        # Create Tenant folder path if it doesn't exist
        $tenantPath = Join-Path -Path $Hawk.FilePath -ChildPath "Tenant"
        if (-not (Test-Path -Path $tenantPath)) {
            New-Item -Path $tenantPath -ItemType Directory -Force | Out-Null
        }

        Test-GraphConnection
        Send-AIEvent -Event "CmdRun"

        # Initialize arrays to collect all results
        $spnResults = @()
        $appResults = @()

        Out-LogFile "Collecting Entra ID Service Principals" -Action
        try {
            $spns = Get-MgServicePrincipal -All | Sort-Object -Property DisplayName
            Out-LogFile "Collecting Entra ID Registered Applications" -Action
            $apps = Get-MgApplication -All | Sort-Object -Property DisplayName
        }
        catch {
            Out-LogFile "Error retrieving Service Principals or Applications: $($_.Exception.Message)" -isError
            Write-Error -ErrorRecord $_ -ErrorAction Continue
        }
    }

    PROCESS {
        try {
            Out-LogFile "Exporting Service Principal Certificate and Password details" -Action
            foreach ($spn in $spns) {
                # Process key credentials
                foreach ($key in $spn.KeyCredentials) {
                    $newapp = [PSCustomObject]@{
                        AppName     = $spn.DisplayName
                        AppObjectID = $spn.Id
                        KeyID       = $key.KeyId
                        StartDate   = $key.StartDateTime
                        EndDate     = $key.EndDateTime
                        KeyType     = $key.Type
                        CredType    = "X509Certificate"
                    }
                    # Add to array for JSON output
                    $spnResults += $newapp
                    # Output individual record to CSV
                    $newapp | Out-MultipleFileType -FilePrefix "SPNCertsAndSecrets" -csv -append
                }

                # Process password credentials
                foreach ($pass in $spn.PasswordCredentials) {
                    $newapp = [PSCustomObject]@{
                        AppName     = $spn.DisplayName
                        AppObjectID = $spn.Id
                        KeyID       = $pass.KeyId
                        StartDate   = $pass.StartDateTime
                        EndDate     = $pass.EndDateTime
                        KeyType     = $null
                        CredType    = "PasswordSecret"
                    }
                    # Add to array for JSON output
                    $spnResults += $newapp
                    # Output individual record to CSV
                    $newapp | Out-MultipleFileType -FilePrefix "SPNCertsAndSecrets" -csv -append
                }
            }

            # Output complete SPN results array as single JSON
            if ($spnResults.Count -gt 0) {
                $spnResults | ConvertTo-Json | Out-File -FilePath (Join-Path -Path $tenantPath -ChildPath "SPNCertsAndSecrets.json")
            }

            Out-LogFile "Exporting Registered Applications Certificate and Password details" -Action
            foreach ($app in $apps) {
                # Process key credentials
                foreach ($key in $app.KeyCredentials) {
                    $newapp = [PSCustomObject]@{
                        AppName     = $app.DisplayName
                        AppObjectID = $app.Id
                        KeyID       = $key.KeyId
                        StartDate   = $key.StartDateTime
                        EndDate     = $key.EndDateTime
                        KeyType     = $key.Type
                        CredType    = "X509Certificate"
                    }
                    # Add to array for JSON output
                    $appResults += $newapp
                    # Output individual record to CSV
                    $newapp | Out-MultipleFileType -FilePrefix "ApplicationCertsAndSecrets" -csv -append
                }

                # Process password credentials
                foreach ($pass in $app.PasswordCredentials) {
                    $newapp = [PSCustomObject]@{
                        AppName     = $app.DisplayName
                        AppObjectID = $app.Id
                        KeyID       = $pass.KeyId
                        StartDate   = $pass.StartDateTime
                        EndDate     = $pass.EndDateTime
                        KeyType     = $pass.Type
                        CredType    = "PasswordSecret"
                    }
                    # Add to array for JSON output
                    $appResults += $newapp
                    # Output individual record to CSV
                    $newapp | Out-MultipleFileType -FilePrefix "ApplicationCertsAndSecrets" -csv -append
                }
            }

            # Output complete application results array as single JSON
            if ($appResults.Count -gt 0) {
                $appResults | ConvertTo-Json | Out-File -FilePath (Join-Path -Path $tenantPath -ChildPath "ApplicationCertsAndSecrets.json")
            }
        }
        catch {
            Out-LogFile "Error processing credentials: $($_.Exception.Message)" -isError
            Write-Error -ErrorRecord $_ -ErrorAction Continue
        }
    }

    END {
        Out-Logfile "Completed exporting Azure AD Service Principal and App Registration Certificate and Password Details" -Information
    }
}