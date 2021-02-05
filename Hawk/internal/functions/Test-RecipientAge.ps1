Function Test-RecipientAge {
<#
.SYNOPSIS
    Check to see if a recipient object was created since our start date
.DESCRIPTION
    Check to see if a recipient object was created since our start date
.PARAMETER RecipientID
    Recipient object ID that is being retrieved
.EXAMPLE
    Test-RecipientAge
    Will test to see if the recipient object was created since the start date
.NOTES
    General notes
#>
    Param([string]$RecipientID)

    $recipient = Get-Recipient -Identity $RecipientID -erroraction SilentlyContinue
    # Verify that we got something back
    if ($null -eq $recipient) {
        Return 2
    }
    # If the date created is newer than our StartDate return non zero (1)
    elseif ($recipient.whencreated -gt $Hawk.StartDate) {
        Return 1
    }
    # If it is older than the start date return 0
    else {
        Return 0
    }

}