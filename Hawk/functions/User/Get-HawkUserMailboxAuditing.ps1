function Get-HawkUserMailboxAuditing {
    <#
.SYNOPSIS
    Gathers Mailbox Audit data if enabled for the user.
.DESCRIPTION
    Checks if mailbox auditing is enabled for the user.
    If it is, pulls the mailbox audit logs from the specified time period.
    Will pull from the Unified Audit Log (UAL) and the Mailbox Audit Log.
.PARAMETER UserPrincipalName
    Single UPN of a user, comma-separated list of UPNs, or array of objects that contain UPNs.
.OUTPUTS

    File: Exchange_UAL_Audit.csv
    Path: <User>
    Description: All Exchange related audit events found in the Unified Audit Log.

    File: Exchange_Mailbox_Audit.csv
    Path: <User>
    Description: All Exchange related audit events found in the Mailbox Audit Log.

.EXAMPLE
    Get-HawkUserMailboxAuditing -UserPrincipalName user@contoso.com

    Search for all Mailbox Audit logs from user@contoso.com.

.EXAMPLE
    Get-HawkUserMailboxAuditing -UserPrincipalName (Get-Mailbox -Filter {Customattribute1 -eq "C-level"})

    Search for all Mailbox Audit logs for all users who have "C-Level" set in CustomAttribute1.
#>

    [CmdletBinding()]
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
        [array]$Results = @()

        do {
            # Get the end of the 5-day range
            [datetime] $RangeEnd = ($RangeStart.AddDays(5))
            Out-LogFile ("Searching Range " + [string]$RangeStart + " To " + [string]$RangeEnd)

            [array]$PartialResults = Search-MailboxAuditLog -StartDate $RangeStart -EndDate $RangeEnd -Identity $User -ShowDetails -ResultSize 250000
            if ($PartialResults) {
                $Results += $PartialResults
            }

            # Advance to the next range
            $RangeStart = $RangeEnd
        }
        while ($RangeStart -le $EndDate)

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
        $mbx = Get-Mailbox -Identity $User
        if ($mbx.AuditEnabled -eq $true) {
            Out-LogFile "Mailbox Auditing is enabled."
            Out-LogFile "Searching Unified Audit Log for Exchange Related Events"

            # Search unified audit logs for Exchange related events
            # Using RecordType ExchangeItem or ExchangeMailbox as needed
            # For now, we'll assume ExchangeItem is appropriate as the old code used ExchangeItem
            $UnifiedAuditResults = Search-UnifiedAuditLog -UserIds $User -RecordType ExchangeItem -StartDate $Hawk.StartDate -EndDate $Hawk.EndDate -Operations "*" -ResultSize 5000

            Out-LogFile ("Found " + $UnifiedAuditResults.Count + " Exchange audit records.")

            # Determine the user's output folder
            $UserFolder = (Get-HawkUserPath -User $User)

            # Write raw JSON to file
            $RawJsonPath = Join-Path $UserFolder "Exchange_UAL_Audit_Raw.json"
            $UnifiedAuditResults | Select-Object -ExpandProperty AuditData | Out-File $RawJsonPath

            # Parse the results using Get-SimpleUnifiedAuditLog
            $ParsedUAL = $UnifiedAuditResults | Get-SimpleUnifiedAuditLog

            # Output the parsed data
            $ParsedUAL | Out-MultipleFileType -FilePrefix "Exchange_UAL_Audit" -User $User -csv -json

            # Now search the mailbox audit logs
            Out-LogFile "Searching Exchange Mailbox Audit Logs (this can take some time)"
            $MailboxAuditLogs = Get-MailboxAuditLogsFiveDaysAtATime -StartDate $Hawk.StartDate -EndDate $Hawk.EndDate -User $User
            Out-LogFile ("Found " + $MailboxAuditLogs.Count + " Exchange Mailbox audit records.")

            # Output mailbox audit logs as before
            $MailboxAuditLogs | Out-MultipleFileType -FilePrefix "Exchange_Mailbox_Audit" -User $User -csv -json
        }
        else {
            Out-LogFile ("Auditing not enabled for " + $User)
        }
    }
}
