# Gets user inbox rules and looks for Investigate rules
Function Get-HawkUserMessageTrace {
    <#
 
	.SYNOPSIS
	Pull that last 7 days of message trace data for the specified user.

	.DESCRIPTION
    Pulls the basic message trace data for the specified user.
    Can only pull the last 7 days as that is all we keep in get-messagetrace

    Further investigation will require Start-HistoricalSearch

	.PARAMETER UserPrincipalName
	Single UPN of a user, commans seperated list of UPNs, or array of objects that contain UPNs.

	.OUTPUTS
	
	File: Message_Trace.csv
	Path: \<User>
	Description: Output of Get-MessageTrace -Sender <primarysmtpaddress>
	
	.EXAMPLE

	Get-HawkUserMessageTrace -UserPrincipalName user@contoso.com

	Gets the message trace for user@contoso.com for the last 7 days

	#>
    
    param
    (
        [Parameter(Mandatory = $true)]
        [array]$UserPrincipalName
	
    )
	
    Test-EXOConnection
    Send-AIEvent -Event "CmdRun"

    # Verify our UPN input
    [array]$UserArray = Test-UserObject -ToTest $UserPrincipalName
	
    # Gather the trace
    foreach ($Object in $UserArray) {

        [string]$User = $Object.UserPrincipalName

        [string]$PrimarySMTP = (Get-Mailbox -identity $User).primarysmtpaddress

        if ([string]::IsNullOrEmpty($PrimarySMTP)) {
            Out-LogFile ("[ERROR] - Failed to find Primary SMTP Address for user: " + $User)
            Write-Error ("Failed to find Primary SMTP Address for user: " + $User)                
        }
        else {
            # Get the 7 day message trace for the primary SMTP address as the sender
            Out-LogFile ("Gathering messages sent by: " + $PrimarySMTP) -action

            (Get-MessageTrace -Sender $PrimarySMTP) | Out-MultipleFileType -FilePreFix "Message_Trace" -user $User -csv
        }
    }
}
