<#
.SYNOPSIS
    Determine if we have an array with UPNs or just a single UPN / UPN array unlabeled
.DESCRIPTION
    Determine if we have an array with UPNs or just a single UPN / UPN array unlabeled
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
Function Test-UserObject {
    param ([array]$ToTest)

    # So we take three inputs here to -userprincipalname string,array,and array of strings
    # We need to test the input value and make sure that that are in a form that the Function can understand
    # The function needs them as an array of object with a property of .UserPrincipalName

    #Case 1 - String
    #Case 2 - Array of Strings
    #Check to see if the value of the entry is of type string
    if ($ToTest[0] -is [string]) {
        # Very basic check to see if this is a UPN
        if ($ToTest[0] -match '@') {
            [array]$Output = $ToTest | Select-Object -Property @{Name = "UserPrincipalName"; Expression = { $_ } }
            Return $Output
        }
        else {
            Out-LogFile "[ERROR] - Unable to determine if input is a UserPrincipalName"
            Out-LogFile "Please provide a UPN or array of objects with propertly UserPrincipalName populated"
            Write-Error "Unable to determine if input is a User Principal Name" -ErrorAction Stop
        }
    }
    # Case 3 - Array of objects
    # Validate that at least one object in the array contains a UserPrincipalName Property
    elseif ([bool](get-member -inputobject $ToTest[0] -name UserPrincipalName -MemberType Properties)) {
        Return $ToTest
    }
    else {
        Out-LogFile "[ERROR] - Unable to determine if input is a UserPrincipalName"
        Out-LogFile "Please provide a UPN or array of objects with propertly UserPrincipalName populated"
        Write-Error "Unable to determine if input is a User Principal Name" -ErrorAction Stop
    }
}
