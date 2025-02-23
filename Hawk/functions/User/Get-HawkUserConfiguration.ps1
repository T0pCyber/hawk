Function Get-HawkUserConfiguration {
	<#
.SYNOPSIS
	Gathers baseline information about the provided user.
.DESCRIPTION
	Gathers and records baseline information about the provided user.
	* Get-EXOMailbox
	* Get-EXOMailboxStatistics
	* Get-EXOMailboxFolderStatistics
	* Get-CASMailbox
.PARAMETER UserPrincipalName
	Single UPN of a user, commans seperated list of UPNs, or array of objects that contain UPNs.
.OUTPUTS

	File: Mailbox_Info.txt
	Path: \<User>
	Description: Output of Get-EXOMailbox for the user

	File: Mailbox_Statistics.txt
	Path : \<User>
	Description: Output of Get-EXOMailboxStatistics for the user

	File: Mailbox_Folder_Statistics.txt
	Path : \<User>
	Description: Output of Get-EXOMailboxFolderStatistics for the user

	File: CAS_Mailbox_Info.txt
	Path : \<User>
	Description: Output of Get-CasMailbox for the user
.EXAMPLE
	Get-HawkUserConfiguration -user bsmith@contoso.com

	Gathers the user configuration for bsmith@contoso.com
.EXAMPLE

	Get-HawkUserConfiguration -UserPrincipalName (Get-EXOMailbox -Filter {Customattribute1 -eq "C-level"})

	Gathers the user configuration for all users who have "C-Level" set in CustomAttribute1
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

		Out-LogFile "Initiating collection of mailbox configuration for $User from Exchange Online." -Action

		#Gather mailbox information
		$mbx = Get-EXOMailbox -Identity $user

		# Test to see if we have an archive and include that info as well
		if (!($null -eq $mbx.archivedatabase)) {
			Get-EXOMailboxStatistics -identity $user -Archive | Out-MultipleFileType -FilePrefix "Mailbox_Archive_Statistics" -user $user -txt
		}

		$mbx | Out-MultipleFileType -FilePrefix "Mailbox_Info" -User $User -txt
		Get-EXOMailboxStatistics -Identity $user | Out-MultipleFileType -FilePrefix "Mailbox_Statistics" -User $User -txt
		Get-EXOMailboxFolderStatistics -identity $user | Out-MultipleFileType -FilePrefix "Mailbox_Folder_Statistics" -User $User -txt

		# Gather cas mailbox sessions
		Out-LogFile "Gathering CAS Mailbox Information" -action
		Get-EXOCasMailbox -identity $user | Out-MultipleFileType -FilePrefix "CAS_Mailbox_Info" -User $User -txt

		Out-LogFile "Completed collection of mailbox configuration for $User from Exchange Online." -Information
	}
}
