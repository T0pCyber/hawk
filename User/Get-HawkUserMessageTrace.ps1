# Gets user inbox rules and looks for Investigate rules
Function Get-HawkUserMessageTrace {
    <#
 
	.SYNOPSIS
	Pulls inbox rules for the specified user.

	.DESCRIPTION
	Gathers inbox rules for the provided uers.
	Looks for rules that forward or delete email and flag them for follow up

	.PARAMETER UserPrincipalName
	Single UPN of a user, commans seperated list of UPNs, or array of objects that contain UPNs.

	.OUTPUTS
	
	File: _Investigate_InboxRules.csv
	Path: \<User>
	Description: Inbox rules that delete or forward messages.

	File: InboxRules.csv
	Path: \<User>
	Description: All inbox rules that were found for the user.

	File: All_InboxRules.csv
	Path: \
	Description: All users inbox rules.
	
	.EXAMPLE

	Get-HawkUserInboxRule -UserPrincipalName user@contoso.com

	Pulls all inbox rules for user@contoso.com and looks for Investigate rules.

	.EXAMPLE

	Get-HawkUserInboxRule -UserPrincipalName (get-mailbox -Filter {Customattribute1 -eq "C-level"})

	Gathers inbox rules for all users who have "C-Level" set in CustomAttribute1

	
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
