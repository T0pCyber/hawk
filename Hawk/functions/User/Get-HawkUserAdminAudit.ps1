Function Get-HawkUserAdminAudit {

    <#

	.SYNOPSIS
	Searches the EXO Audit logs for any commands that were run against the provided user object.

	.DESCRIPTION
    Searches the EXO Audit logs for any commands that were run against the provided user object.
    Limited by the provided search period.

	.OUTPUTS

	File: Simple_User_Changes.csv
	Path: \<user>
	Description: All cmdlets that were run against the user in a simple format.

	.EXAMPLE
    Get-HawkUserAdminAudit -UserPrincipalName user@company.com

    Gets all changes made to user@company.com and ouputs them to the csv and xml files.

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

    Foreach ($Object in $UserArray) {
        [string]$User = $Object.UserPrincipalName

        # Get the mailbox name since that is what we store in the admin audit log
        $MailboxName = (Get-Mailbox -identity $User).name

        Out-LogFile ("Searching for changes made to: " + $MailboxName) -action

        # Get all changes to this user from the admin audit logs
        [array]$UserChanges = Search-AdminAuditLog -ObjectIDs $MailboxName -StartDate $Hawk.StartDate -EndDate $Hawk.EndDate


        # If there are any results push them to an output file
        if ($UserChanges.Count -gt 0) {
            Out-LogFile ("Found " + $UserChanges.Count + " changes made to this user")
            $UserChanges | Get-SimpleAdminAuditLog | Out-MultipleFileType -FilePrefix "Simple_User_Changes" -csv -user $User
            $UserChanges | Out-MultipleFileType -FilePrefix "User_Changes" -csv -user $User
        }
        # Otherwise report no results found
        else {
            Out-LogFile "No User Changes found."
        }

    }
}
