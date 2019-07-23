Function Get-HawkUserPWNCheck {
    <#
 
	.SYNOPSIS
	Checks an email address against haveibeenpwned.com

	.DESCRIPTION
	Checks a single email address against HaveIBeenPwned. Note this will require an API key soon

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

    # Verify our UPN input
    [array]$UserArray = Test-UserObject -ToTest $Email

    foreach ($Object in $UserArray) {

        $[string]$User = $Object.UserPrincipalName

        # Convert the email to URL encoding
        $uriEncodeEmail = [uri]::EscapeDataString($($user))

        # Build and invoke the URL
        $InvokeURL = 'https://haveibeenpwned.com/api/v2/breachedaccount/' + $uriEncodeEmail
        $Error.clear()

        try {
            $Result = Invoke-WebRequest $InvokeURL -userAgent 'Hawk' -ErrorAction Stop
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
