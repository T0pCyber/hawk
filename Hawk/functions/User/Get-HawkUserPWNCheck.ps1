Function Get-HawkUserPWNCheck {
    <#
    .SYNOPSIS
        Checks an email address against haveibeenpwned.com
    .DESCRIPTION
        Checks a single email address against HaveIBeenPwned. An API key is required and can be obtained from https://haveibeenpwned.com/API/Key for $3.50 a month.
        This script will prompt for the key if $hibpkey is not set as a variable.
    .PARAMETER Email
        Accepts since EMail address or array of Email address strings.
        DOES NOT Accept an array of objects (it will end up checked the UPN and not the email address)
    .OUTPUTS
        File: Have_I_Been_Pwned.txt
        Path: \<user>
        Description: Information returned from the pwned database
    .EXAMPLE
        Start-HawkUserPWNCheck -Email user@company.com

        Returns the pwn state of the email address provided
    #>
    param([array]$Email)

    if ($null -eq $hibpkey) {
        Write-Information "
        HaveIBeenPwned.com now requires an API access key to gather Stats with from their API.
        Please purchase an API key for $3.50 a month from get a Free access key from https://haveibeenpwned.com/API/Key and provide it below.
        " -InformationAction Continue

        $hibpkey = Read-Host "haveibeenpwned.com apikey"
    }

    [array]$UserArray = Test-UserObject -ToTest $Email
    $headers = @{ 'hibp-api-key' = $hibpkey }

    foreach ($Object in $UserArray) {
        $User = [string]$Object.UserPrincipalName
        $uriEncodeEmail = [uri]::EscapeDataString($User)

        $InvokeURL = 'https://haveibeenpwned.com/api/v3/breachedaccount/' + $uriEncodeEmail + '?truncateResponse=false'
        $Error.Clear()

        try {
            $Result = Invoke-WebRequest $InvokeURL -Headers $headers -UserAgent 'Hawk' -ErrorAction Stop
        }
        catch {
            switch ($Error[0].Exception.Response.StatusCode) {
                NotFound {
                    Write-Output "Email Not Found to be Pwned"
                    return
                }
                Default {
                    Write-Error "[ERROR] - Failure to retrieve pwned status"
                    Write-Output $Error
                    return
                }
            }
        }

        $Pwned = $Result.Content | ConvertFrom-Json
        Out-LogFile ("Email Address found in " + $Pwned.Count) -Notice
        $Pwned | Out-MultipleFileType -FilePrefix "Have_I_Been_Pwned" -User $User -Txt

        Start-Sleep -Milliseconds 1500
    }
}
