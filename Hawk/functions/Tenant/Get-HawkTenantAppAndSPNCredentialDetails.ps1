Function Get-HawkTenantAppAndSPNCredentialDetails {
<#
.SYNOPSIS
    Tenant Azure Active Directory Applications and Service Principal Credential details export. Must be connected to Azure-AD using the Connect-AzureAD cmdlet
.DESCRIPTION
    Tenant Azure Active Directory Applications and Service Principal Credential details export. Credential details can be used to
    review when credentials were created for an Application or Service Principal. If a malicious user created a certificat or password
    used to access corporate data, then knowing the key creation time will intrumental to determing the time frame of when an attacker
    had access to data.
.EXAMPLE
    PS C:\>Get=HawkTenantAppAndSPNCredentialDetals
.OUTPUTS
    SPNCertsAndSecrets.csv
    ApplicationCertsAndSecrets
.LINK
    https://docs.microsoft.com/en-us/azure/active-directory/develop/app-objects-and-service-principals
    https://docs.microsoft.com/en-us/powershell/module/azuread/get-azureadapplicationkeycredential?view=azureadps-2.0

.NOTES

#>
BEGIN{
    Out-LogFile "Collecting Azure AD Service Principals"
    $spns = get-azureadserviceprincipal -all $true | Sort-Object -Property DisplayName
    Out-LogFile "Collecting Azure AD Registered Applications"
    $apps = Get-AzureADApplication -all $true | Sort-Object -Property DisplayName
}

PROCESS{
    Out-LogFile "Exporting Service Principal Certificate and Password details"
    foreach ($spn in $spns) {
        $keys = $spn.keycredentials
        foreach ($key in $keys){
            $newapp = [PSCustomObject]@{
                AppName = $spn.DisplayName
                AppObjectID = $spn.ObjectID
                KeyID = $key.KeyID
                StartDate = $key.startdate
                EndDate = $key.endDate
                KeyType = $Key.Type
                CredType = "X509Certificate"

            }
            $newapp | Out-MultipleFileType -FilePrefix "SPNCertsAndSecrets" -csv -append

        }
    }
    foreach ($spn in $spns) {
        $passwords = $spn.PasswordCredentials
        foreach ($pass in $passwords){
            $newapp = [PSCustomObject]@{
                AppName = $spn.DisplayName
                AppObjectID = $spn.ObjectID
                KeyID = $pass.KeyID
                StartDate = $pass.startdate
                EndDate = $pass.endDate
                KeyType = $null
                CredType = "PasswordSecret"
            }
            $newapp | Out-MultipleFileType -FilePrefix "SPNCertsAndSecrets" -csv -append

        }

    }
    Out-LogFile "Exporting Registered Applications Certificate and Password details"
    foreach ($app in $apps) {
        $keys = $app.keycredentials
        foreach ($key in $keys){
            $newapp = [PSCustomObject]@{
                AppName = $app.DisplayName
                AppObjectID = $app.ObjectID
                KeyID = $key.KeyID
                StartDate = $key.startdate
                EndDate = $key.endDate
                KeyType = $Key.Type
                CredType = "X509Certificate"

            }
            $newapp | Out-MultipleFileType -FilePrefix "ApplicationCertsAndSecrets" -csv -append

        }

    }
    foreach ($app in $apps) {
        $passwords = $app.PasswordCredentials
        foreach ($pass in $passwords){
            $newapp = [PSCustomObject]@{
                AppName = $app.DisplayName
                AppObjectID = $app.ObjectID
                KeyID = $pass.KeyID
                StartDate = $pass.startdate
                EndDate = $pass.endDate
                KeyType = $pass.Type
                CredType = "PasswordSecret"

            }
            $newapp | Out-MultipleFileType -FilePrefix "ApplicationCertsAndSecrets" -csv -append

        }
    }
}#End Process
END{
    Out-Logfile "Completed exporting Azure AD Serice Principal and App Registration Certificate and Password Details"
} #End End

}#End Function
