Function Get-HawkUserPWNCheck {
   <#
   .SYNOPSIS
       Checks an email address against haveibeenpwned.com
   .DESCRIPTION
       Checks a single email address against HaveIBeenPwned. An API key is required and can be obtained from https://haveibeenpwned.com/API/Key for $3.50 a month.
       This script will prompt for the key if $hibpkey is not set as a variable.
   .PARAMETER EmailAddress
       Accepts since EMail address or array of Email address strings.
       DOES NOT Accept an array of objects (it will end up checked the UPN and not the email address)
   .OUTPUTS
       File: Have_I_Been_Pwned.txt
       Path: \<user>
       Description: Information returned from the pwned database
   .EXAMPLE
       Get-HawkUserPWNCheck -EmailAddress user@company.com

       Returns the pwn state of the email address provided
   #>

       param(
           [string[]]$EmailAddress
           )

       BEGIN {
           # Check if Hawk object exists and is fully initialized
           if (Test-HawkGlobalObject) {
               Initialize-HawkGlobalObject
           }

           if ($null -eq $hibpkey) {
               Write-Host -ForegroundColor Green "

               HaveIBeenPwned.com now requires an API access key to gather Stats with from their API.

               Please purchase an API key for `$3.95 a month from get a Free access key from https://haveibeenpwned.com/API/Key and provide it below.

               "

               # get the access key from the user
               Out-LogFile "haveibeenpwned.com apikey" -isPrompt -NoNewLine
               $hibpkey = Read-Host 
           }
       }#End of BEGIN block

       # Verify our UPN input
       PROCESS {
            # Used to silence PSSA parameter usage warning
            if ($null -eq $EmailAddress) { return }
           [array]$UserArray = Test-UserObject -ToTest $EmailAddress
           $headers=@{'hibp-api-key' = $hibpkey}

           foreach ($Object in $UserArray) {

               [string]$User = $Object.UserPrincipalName

               # Convert the email to URL encoding
               $uriEncodeEmail = [uri]::EscapeDataString($($user))

               # Build and invoke the URL
               $InvokeURL = 'https://haveibeenpwned.com/api/v3/breachedaccount/' + $uriEncodeEmail + '?truncateResponse=false'
               $Error.clear()
               #Will catch the error if the email is not found. 404 error means that the email is not found in the database.
               #https://haveibeenpwned.com/API/v3#ResponseCodes contains the response codes for the API
               try {
                   $Result = Invoke-WebRequest -Uri $InvokeURL -Headers $headers -userAgent 'Hawk' -ErrorAction Stop
               }
               catch {
                   $StatusCode = $_.Exception.Response.StatusCode
                   $ErrorMessage = $_.Exception.Message
                   switch ($StatusCode) {
                       NotFound{
                           write-host "Email Provided Not Found in Pwned Database"
                           return
                       }
                       Unauthorized{
                           write-host "Unauthorised Access - API key provided is not valid or has expired"
                           return
                       }
                       Default {
                           write-host $ErrorMessage
                           return
                       }
                   }
               }

               # Convert the result into a PS custgom object
               $Pwned = $Result.content | ConvertFrom-Json

               # Output the value
               Out-LogFile ("Email Address found in " + $pwned.count)
               $Pwned | Out-MultipleFileType -FilePreFix "Have_I_Been_Pwned" -user $user -txt

           }
       }#End of PROCESS block
       
       END {
           Start-Sleep -Milliseconds 1500
       }#End of END block
}#End of Function Get-HawkUserPWNCheck