Function Get-HawkUserConfiguration {

    <#
 
	.SYNOPSIS
	Gathers baseline information about the provided user.

	.DESCRIPTION
	Gathers and records baseline information about the provided user.
	
	* Get-Mailbox
	* Get-MailboxStatistics
	* Get-MailboxFolderStatistics
	* Get-CASMailbox
	
	.PARAMETER UserPrincipalName
	Single UPN of a user, commans seperated list of UPNs, or array of objects that contain UPNs.

	.OUTPUTS

	File: Mailbox_Info.txt
	Path: \<User>
	Description: Output of Get-Mailbox for the user

	File: Mailbox_Statistics.txt
	Path : \<User>
	Description: Output of Get-MailboxStatistics for the user

	File: Mailbox_Folder_Statistics.txt
	Path : \<User>
	Description: Output of Get-MailboxFolderStatistics for the user

	File: CAS_Mailbox_Info.txt
	Path : \<User>
	Description: Output of Get-CasMailbox for the user

	.EXAMPLE
	Get-HawkUserConfiguration -user bsmith@contoso.com

	Gathers the user configuration for bsmith@contoso.com

	.EXAMPLE

	Get-HawkUserConfiguration -UserPrincipalName (get-mailbox -Filter {Customattribute1 -eq "C-level"})

	Gathers the user configuration for all users who have "C-Level" set in CustomAttribute1

	
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

    foreach ($Object in $UserArray) {
        [string]$User = $Object.UserPrincipalName

        Out-LogFile ("Gathering information about " + $User) -action

        #Gather mailbox information
        Out-LogFile "Gathering Mailbox Information"
		$mbx = Get-Mailbox -identity $user
		
		# Test to see if we have an archive and include that info as well
		if (!($null -eq $mbx.archivedatabase)){
			Get-MailboxStatistics -identity $user -Archive | Out-MultipleFileType -FilePrefix "Mailbox_Archive_Statistics" -user $user -txt
		}		
		
		$mbx | Out-MultipleFileType -FilePrefix "Mailbox_Info" -User $User -txt
        Get-MailboxStatistics -identity $user | Out-MultipleFileType -FilePrefix "Mailbox_Statistics" -User $User -txt
        Get-MailboxFolderStatistics -identity $user | Out-MultipleFileType -FilePrefix "Mailbox_Folder_Statistics" -User $User -txt

        # Gather cas mailbox sessions
        Out-LogFile "Gathering CAS Mailbox Information"
        Get-CasMailbox -identity $user | Out-MultipleFileType -FilePrefix "CAS_Mailbox_Info" -User $User -txt
    }	
}
