function Get-HawkUserMailboxAuditing {

    <#

	.SYNOPSIS
	Gathers Mailbox Audit data if enabled for the user.

	.DESCRIPTION
	Check if mailbox auditing is enabled for the user.
    If it is pulls the mailbox audit logs from the time period specified for the investigation.

    Will pull from the Unified Audit Log and the Mailbox Audit Log

	.PARAMETER UserPrincipalName
	Single UPN of a user, commans seperated list of UPNs, or array of objects that contain UPNs.

	.OUTPUTS

	File: Exchange_UAL_Audit.csv
	Path: \<User>
	Description: All Exchange related audit events found in the Unified Audit Log.

    File: Exchange_Mailbox_Audit.csv
	Path: \<User>
	Description: All Exchange related audit events found in the Mailbox Audit Log.


	.EXAMPLE

	Get-HawkUserMailboxAuditing -UserPrincipalName user@contoso.com

	Search for all Mailbox Audit logs from user@contoso.com

	.EXAMPLE

	Get-HawkUserMailboxAuditing -UserPrincipalName (get-mailbox -Filter {Customattribute1 -eq "C-level"})

	Search for all Mailbox Audit logs for all users who have "C-Level" set in CustomAttribute1

    #>

    param
    (
        [Parameter(Mandatory = $true)]
        [array]$UserPrincipalName
    )

    Function Get-MailboxAuditLogsFiveDaysAtATime {
        param(
            [Parameter(Mandatory = $true)]
            [datetime]$StartDate,
            [Parameter(Mandatory = $true)]
            [datetime]$EndDate,
            [Parameter(Mandatory = $true)]
            $User
        )


        # Setup the initial start date
        [datetime]$RangeStart = $StartDate

        do {
            # Get the end of the Range we are going to gather data for
            [string]$RangeEnd =[datetime]::parse($RangeStart, [CultureInfo]::CreateSpecificCulture("en-US")).AddDays(5).toString("MM/dd/yyyy")

            # Do the actual search
            Out-LogFile ("Searching Range " + [string]$RangeStart + " To " + [string]$RangeEnd)
            [array]$Results += Search-MailboxAuditLog -StartDate $RangeStart -EndDate $RangeEnd -identity $User -ShowDetails -ResultSize 250000

            # Set the RangeStart = to the RangeEnd so we do the next range
            $RangeStart = $RangeEnd
        }
        # While the start range is less than the end date we need to keep pulling in 5 day increments
        while ($RangeStart -le $EndDate)

        # Return the results object
        Return $Results

    }

    ### MAIN ###
    Test-EXOConnection
    Send-AIEvent -Event "CmdRun"

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
            Out-LogFile "Searching Unified Audit Log for Exchange Related Events"

            $UnifiedAuditLogs = Get-AllUnifiedAuditLogEntry -UnifiedSearch ("Search-UnifiedAuditLog -UserIDs " + $User + " -RecordType ExchangeItem")
            Out-LogFile ("Found " + $UnifiedAuditLogs.Count + " Exchange audit records.")

            # Output the data we found
            $UnifiedAuditLogs | Out-MultipleFileType -FilePrefix "Exchange_UAL_Audit" -User $User -csv

            # Search the MailboxAuditLogs as well since they may have different/more information
            Out-LogFile "Searching Exchange Mailbox Audit Logs (this can take some time)"

            $MailboxAuditLogs = Get-MailboxAuditLogsFiveDaysAtATime -StartDate $Hawk.StartDate -EndDate $Hawk.EndDate -User $User
            Out-LogFile ("Found " + $MailboxAuditLogs.Count + " Exchange Mailbox audit records.")

            # Output the data we found
            $MailboxAuditLogs | Out-MultipleFileType -FilePrefix "Exchange_Mailbox_Audit" -User $User -csv

        }
        # If auditing is not enabled log it and move on
        else {
            Out-LogFile ("Auditing not enabled for " + $User)
        }
    }
}
