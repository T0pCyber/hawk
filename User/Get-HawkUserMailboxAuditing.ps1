# Get any unified audit logs related to mailbox auditing if enabled
function Get-HawkUserMailboxAuditing {
    param
    (
        [Parameter(Mandatory = $true)]
        [array]$UserPrincipalName
    )

    Test-EXOConnection
    Send-AIEvent -Event "CmdRun" -Properties @{"cmdlet"="Get-HawkUserMailboxAuditing"}

    # Verify our UPN input
    [array]$UserArray = Test-UserObject -ToTest $UserPrincipalName

    foreach ($Object in $UserArray) {
        [string]$User = $Object.UserPrincipalName

        Out-LogFile ("Attempting to Gather Mailbox Audit logs " + $User) -action

        # Test if mailbox auditing is enabled
        $mbx = Get-Mailbox -identity $User
        if ($mbx.AuditEnabled -eq $true) {
            # if enabled pull the mailbox auditing from the unified audit logs
            Out-LogFile "Mailbox Auditing is enabled."
            Out-LogFile "Searching for Exchange related Audit Logs"
            $UserLogonLogs = Get-AllUnifiedAuditLogEntry -UnifiedSearch ("Search-UnifiedAuditLog -UserIDs " + $User + " -RecordType ExchangeItem")
		
            Out-LogFile ("Found " + $UserLogonLogs.Count + " Exchange audit records.")

            # Output the data we found
            $UserLogonLogs | Out-MultipleFileType -FilePrefix "Exchange_Audit" -User $User -xml -csv
			
        }
        # If auditing is not enabled log it and move on
        else {
            Out-LogFile ("Auditing not enabled for " + $User)
        }
    }

    <#
 
	.SYNOPSIS
	Gathers Mailbox Audit data if enabled for the user.

	.DESCRIPTION
	Check if mailbox auditing is enabled for the user.
	If it is pulls the mailbox audit logs fromt he time period specified for the investigation.

	.PARAMETER UserPrincipalName
	Single UPN of a user, commans seperated list of UPNs, or array of objects that contain UPNs.

	.OUTPUTS
	
	File: Exchange_Audit.csv
	Path: \<User>
	Description: All exchange related audit events found.

	File: Exchange_Audit.xml
	Path: \<User>\xml
	Description: Client XML of all Exchange related audit events (Large file).
	
	.EXAMPLE

	Get-HawkUserMailboxAuditing -UserPrincipalName user@contoso.com

	Search for all Mailbox Audit logs from user@contoso.com

	.EXAMPLE

	Get-HawkUserMailboxAuditing -UserPrincipalName (get-mailbox -Filter {Customattribute1 -eq "C-level"})

	Search for all Mailbox Audit logs for all users who have "C-Level" set in CustomAttribute1
	
	#>

}