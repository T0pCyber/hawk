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

    # if there is no value of hibpkey then we need to get it from the user
    if ($null -eq $hibpkey) {

        Write-Host -ForegroundColor Green "

        HaveIBeenPwned.com now requires an API access key to gather Stats with from their API.

        Please purchase an API key for $3.50 a month from get a Free access key from https://haveibeenpwned.com/API/Key and provide it below.

        "

        # get the access key from the user
        $hibpkey = Read-Host "haveibeenpwned.com apikey"
    }
    
    # Verify our UPN input
    [array]$UserArray = Test-UserObject -ToTest $Email
    $headers=@{'hibp-api-key' = $hibpkey}

    foreach ($Object in $UserArray) {

        $[string]$User = $Object.UserPrincipalName

        # Convert the email to URL encoding
        $uriEncodeEmail = [uri]::EscapeDataString($($user))

        # Build and invoke the URL
        $InvokeURL = 'https://haveibeenpwned.com/api/v3/breachedaccount/' + $uriEncodeEmail + '?truncateResponse=false'
        $Error.clear()

        try {
            $Result = Invoke-WebRequest $InvokeURL -Headers $headers -userAgent 'Hawk' -ErrorAction Stop
        }
        catch {
            switch ($Error[0].exception.response.statuscode) {
                NotFound {
                    write-host "Email Not Found to be Pwned"
                    return
                }
                Default {
                    write-host "[ERROR] - Failure to retrieve pwned status"
                    write-host $Error
                    return
                }
            }
        }
    
        # Convert the result into a PS object
        $Pwned = $Result.content | ConvertFrom-Json
    
        # Output the value
        Out-LogFile ("Email Address found in " + $pwned.count)
        $Pwned | Out-MultipleFileType -FilePreFix "Have_I_Been_Pwned" -user $user -txt

        Start-Sleep -Milliseconds 1500
    }
}
