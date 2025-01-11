Function Get-HawkUserAutoReply {
<#
.SYNOPSIS
    Pulls AutoReply Configuration for the specified user.
.DESCRIPTION
    Gathers AutoReply configuration for the provided users.
    Looks for AutoReplyState of Enabled and exports the config.
.PARAMETER UserPrincipalName
    Single UPN of a user, commans seperated list of UPNs, or array of objects that contain UPNs.
.OUTPUTS

    File: AutoReply.txt
    Path: \<User>
    Description: AutoReplyConfiguration for the user.
.EXAMPLE

    Get-HawkUserAutoReply -UserPrincipalName user@contoso.com

    Pulls AutoReplyConfiguration for user@contoso.com and looks for AutoReplyState Enabled.
.EXAMPLE

    Get-HawkUserAutoReply -UserPrincipalName (get-mailbox -Filter {Customattribute1 -eq "C-level"})

    Gathers AutoReplyConfiguration for all users who have "C-Level" set in CustomAttribute1
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

        # Get Autoreply Configuration
        Out-LogFile ("Retrieving AutoReply Configuration: " + $User) -action
        $AutoReply = Get-MailboxAutoReplyConfiguration -Identity  $User

        # Check if the Autoreply is Disabled
        if ($AutoReply.AutoReplyState -eq 'Disabled') {

            Out-LogFile "AutoReply is not enabled or not configured." -Information
        }
        # Output Enabled AutoReplyConfiguration to a generic txt
        else {

            $AutoReply | Out-MultipleFileType -FilePreFix "AutoReply" -User $user -txt
        }
    }

}
