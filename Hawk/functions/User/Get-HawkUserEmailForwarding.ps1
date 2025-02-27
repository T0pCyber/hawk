﻿Function Get-HawkUserEmailForwarding {
    <#
	.SYNOPSIS
	Pulls mail forwarding configuration for a specified user.
	.DESCRIPTION
	Pulls the values of ForwardingSMTPAddress and ForwardingAddress to see if the user has these configured.
	.PARAMETER UserPrincipalName
	Single UPN of a user, commans seperated list of UPNs, or array of objects that contain UPNs.
	.OUTPUTS

	File: _Investigate_Users_WithForwarding.csv
	Path: \
	Description: All users that are found to have forwarding configured.

	File: User_ForwardingReport.csv
	Path: \
	Description: Mail forwarding configuration for all searched users; even if null.

	File: ForwardingReport.csv
	Path: \<user>
	Description: Forwarding confiruation of the searched user.
	.EXAMPLE

	Get-HawkUserEmailForwarding -UserPrincipalName user@contoso.com

	Gathers possible email forwarding configured on the user.

    .EXAMPLE

	Get-HawkUserEmailForwarding -UserPrincipalName (get-mailbox -Filter {Customattribute1 -eq "C-level"})

	Gathers possible email forwarding configured for all users who have "C-Level" set in CustomAttribute1
    #>

    param
    (
        [Parameter(Mandatory = $true)]
        [array]$UserPrincipalName
    )

    # Check if Hawk object exists and is fully initialized
    if (Test-HawkGlobalObject) {
        Initialize-HawkGlobalObject
    }
    

    Test-EXOConnection
    Send-AIEvent -Event "CmdRun"

    # Verify our UPN input
    [array]$UserArray = Test-UserObject -ToTest $UserPrincipalName

    foreach ($Object in $UserArray) {

        [string]$User = $Object.UserPrincipalName

        # Looking for email forwarding stored in AD
        Out-LogFile "Initiating collection of email forwarding configuration for $User from Exchange Online." -Action
        $mbx = Get-Mailbox -identity $User

        # Check if forwarding is configured by user or admin
        if ([string]::IsNullOrEmpty($mbx.ForwardingSMTPAddress) -and [string]::IsNullOrEmpty($mbx.ForwardingAddress)) {
            Out-LogFile "Get-HawkUserEmailForwarding completed successfully" -Information
            Out-LogFile "No forwarding configuration found" -action
        }
        # If populated report it and add to a CSV file of positive finds
        else {
            Out-LogFile "Found email forwarding configured for $User" -Notice
            Out-LogFile "Please verify this activity is legitimate." -Notice
            $mbx | Select-Object DisplayName, UserPrincipalName, PrimarySMTPAddress, ForwardingSMTPAddress, ForwardingAddress, DeliverToMailboxAndForward, WhenChangedUTC | Out-MultipleFileType -FilePreFix "_Investigate_Users_WithForwarding" -append -user $user -csv -json -Notice
        }

        # Add all users searched to a generic output
        $mbx | Select-Object DisplayName, UserPrincipalName, PrimarySMTPAddress, ForwardingSMTPAddress, ForwardingAddress, DeliverToMailboxAndForward, WhenChangedUTC | Out-MultipleFileType -FilePreFix "User_ForwardingReport" -append -csv -json
        # Also add to an output specific to this user
        $mbx | Select-Object DisplayName, UserPrincipalName, PrimarySMTPAddress, ForwardingSMTPAddress, ForwardingAddress, DeliverToMailboxAndForward, WhenChangedUTC | Out-MultipleFileType -FilePreFix "ForwardingReport" -user $user -csv -json

        Out-LogFile "Completed collection of email forwarding configuration for $User from Exchange Online." -Information

    }
}