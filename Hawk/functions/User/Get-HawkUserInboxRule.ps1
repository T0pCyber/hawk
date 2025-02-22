# Gets user inbox rules and looks for Investigate rules
Function Get-HawkUserInboxRule {
<#
.SYNOPSIS
    Exports inbox rules for the specified user.
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

        # Get Inbox rules
        Out-LogFile ("Gathering Inbox Rules: " + $User) -action
        $InboxRules = Get-InboxRule -mailbox  $User

        if ($null -eq $InboxRules) { 
            Out-LogFile "Get-HawkUserInboxRule completed successfully" -Information
            Out-LogFile "No Inbox Rules found" -action
        } 
        else {
            # Track if we found any suspicious rules
            $foundSuspiciousRules = $false
            
            # If the rules contains one of a number of known suspicious properties flag them
            foreach ($Rule in $InboxRules) {
                # Set our flag to false
                $Investigate = $false

                # Evaluate each of the properties that we know bad actors like to use and flip the flag if needed
                if ($Rule.DeleteMessage -eq $true) { $Investigate = $true }
                if (!([string]::IsNullOrEmpty($Rule.ForwardAsAttachmentTo))) { $Investigate = $true }
                if (!([string]::IsNullOrEmpty($Rule.ForwardTo))) { $Investigate = $true }
                if (!([string]::IsNullOrEmpty($Rule.RedirectTo))) { $Investigate = $true }

                # If we have set the Investigate flag then output to investigation file
                if ($Investigate -eq $true) {
                    $foundSuspiciousRules = $true
                    # Description is multiline
                    $Rule.Description = $Rule.Description.replace("`r`n", " ").replace("`t", "")
                    $Rule | Out-MultipleFileType -FilePreFix "_Investigate_InboxRules" -user $user -csv -json -append
                }
            }

            # Output notice only once if suspicious rules were found
            if ($foundSuspiciousRules) {
                $suspiciousRuleCount = ($InboxRules | Where-Object { 
                    $_.DeleteMessage -eq $true -or 
                    ![string]::IsNullOrEmpty($_.ForwardAsAttachmentTo) -or 
                    ![string]::IsNullOrEmpty($_.ForwardTo) -or 
                    ![string]::IsNullOrEmpty($_.RedirectTo)
                }).Count

                Out-LogFile "Found $suspiciousRuleCount inbox rules requiring investigation for $User" -Notice
                Out-LogFile "Please verify this activity is legitimate. Details in _Investigate_InboxRules.csv/json" -Notice
            }

			# Description is multiline
			$inboxrulesRawDescription = $InboxRules
			$InboxRules = New-Object -TypeName "System.Collections.ArrayList"

			$inboxrulesRawDescription | ForEach-Object {
				$_.Description = $_.Description.Replace("`r`n", " ").replace("`t", "")

				$null = $InboxRules.Add($_)
			}

            # Output all of the inbox rules to a generic csv
            $InboxRules | Out-MultipleFileType -FilePreFix "InboxRules" -User $user -csv -json

            # Add all of the inbox rules to a generic collection file
            $InboxRules | Out-MultipleFileType -FilePrefix "All_InboxRules" -User $user -csv -json -Append
        }

        # Get any Sweep Rules
        # Suggested by Adonis Sardinas
        Out-LogFile ("Gathering Sweep Rules: " + $User) -action
        $SweepRules = Get-SweepRule -Mailbox $User

        if ($null -eq $SweepRules) { Out-LogFile "No Sweep Rules found" -Information}
        else {

            # Output all rules to a user CSV
            $SweepRules | Out-MultipleFileType -FilePreFix "SweepRules" -user $User -csv -json

            # Add any found to the whole tenant list
            $SweepRules | Out-MultipleFileType -FilePreFix "All_SweepRules" -csv -json -append

        }
    }
}
