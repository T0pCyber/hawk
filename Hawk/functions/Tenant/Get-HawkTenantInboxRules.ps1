Function Get-HawkTenantInboxRules {

    <#
 
	.SYNOPSIS
	Gets inbox rules and forwarding directly from all mailboxes in the org.

	.DESCRIPTION
	Uses Start-RobustCloudCommand to gather data from each mailbox in the org.
	Gathers inbox rules with Get-HawkUserInboxRule
	Gathers forwarding with Get-HawkUserEmailForwarding

	.PARAMETER CSVPath
	Path to a CSV file with a list of users to run against.
	CSV header should have DisplayName,PrimarySMTPAddress at minimum

	.OUTPUTS
	
	See Help for Get-HawkUserInboxRule for inbox rule output
	See Help for Get-HawkUserEmailForwarding for email forwarding output

	File: Robust.log
	Path: \
	Description: Logfile for Start-RobustCloudCommand
		
	.EXAMPLE
	Start-HawkTenantInboxRules
	
	Runs Get-HawkUserInboxRule and Get-HawkUserEmailForwarding against all mailboxes in the org

	.EXAMPLE
	Start-HawkTenantInboxRules -csvpath c:\temp\myusers.csv

	Runs Get-HawkUserInboxRule and Get-HawkUserEmailForwarding against all mailboxes listed in myusers.csv

	.LINK
	https://gallery.technet.microsoft.com/office/Start-RobustCloudCommand-69fb349e

	
    #>
    
    param ([string]$CSVPath)


    Test-EXOConnection
    Send-AIEvent -Event "CmdRun"

    # Prompt the user that this is going to take a long time to run
    $title = "Long Running Command"
    $message = "Running this search can take a very long time to complete (~1min per user). `nDo you wish to continue?"
    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Continue operation"
    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Exit Cmdlet"
    $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
    $result = $host.ui.PromptForChoice($title, $message, $options, 0) 
    # If yes log and continue
    # If no log error and exit
    switch ($result) {
        0 { Out-LogFile "Starting full Tenant Search" }
        1 { Write-Error -Message "User Stopped Cmdlet" -ErrorAction Stop }
    }

    # Get the exo PS session
    $exopssession = get-pssession | Where-Object { ($_.ConfigurationName -eq 'Microsoft.Exchange') -and ($_.State -eq 'Opened') }

    # Gather all of the mailboxes
    Out-LogFile "Getting all Mailboxes"
	
    # If we don't have a value for csvpath then gather all users in the tenant
    if ([string]::IsNullOrEmpty($CSVPath)) {
        $AllMailboxes = Invoke-Command -Session $exopssession -ScriptBlock { Get-Recipient -RecipientTypeDetails UserMailbox -ResultSize Unlimited | Select-Object -Property DisplayName, PrimarySMTPAddress }
        $Allmailboxes | Out-MultipleFileType -FilePrefix "All_Mailboxes" -csv
    }
    # If we do read that in
    else {
        # Import the csv with error checking
        $error.clear()
        $AllMailboxes = Import-Csv $CSVPath
        if ($error.Count -gt 0) {
            Write-Error "Problem importing csv file aborting" -ErrorAction Stop
        }
    }
	
    # Report how many mailboxes we are going to operate on
    Out-LogFile ("Found " + $AllMailboxes.count + " Mailboxes")

    # Get the path to start-robustcloudcommand
    # [string]$scriptpath = "& `'" + (Join-Path (Split-path ((get-module Hawk).path) -Parent) "Start-RobustCloudCommand.ps1") + "`'"
    
    # get EXO Credentials
    # Out-LogFile "Gathering EXO Admin Credentials"
    # $cred = Get-Credential -Message "EXO Credentials"

    # Path for robust log file
    $RobustLog = Join-path $Hawk.FilePath "Robust.log"

    # Build the command we are going to need to run with start-robustcloudcommand
    $cmd = "Start-RobustCloudCommand -logfile `$RobustLog -recipients `$AllMailboxes -scriptblock {Get-HawkUserInboxRule -UserPrincipalName `$input.PrimarySmtpAddress.tostring()}"
       
    # Invoke our Start-Robust command to get all of the inbox rules
    Out-LogFile "===== Starting Robust Cloud Command to Gather User Specific information from all tenant users ====="
    Out-LogFile $cmd
    Invoke-Expression $cmd

    Out-LogFile "Process Complete"	
}