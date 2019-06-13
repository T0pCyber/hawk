Function Get-HawkUserPWNCheck {
    param()


    $uriEncodeEmail = [uri]::EscapeDataString($email)

    https://haveibeenpwned.com/api/v2/breachedaccount/user%40company.com?User-Agent=Hawk



}