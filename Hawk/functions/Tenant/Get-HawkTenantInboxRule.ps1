﻿Function Get-HawkTenantInboxRule {
    <#
    .SYNOPSIS
        Retrieves the currently active inbox rules and forwarding settings from all (or specified) mailboxes.

    .DESCRIPTION
        This function directly queries each mailbox in the organization to list its currently configured 
        inbox rules and email forwarding settings. It provides a real-time snapshot of what rules are 
        active right now, as opposed to historical audit data.

        Key points:
        - Directly collects the current state of each mailbox’s rules using Get-HawkUserInboxRule.
        - Also gathers forwarding settings from Get-HawkUserEmailForwarding.
        - Does not rely on audit logs; instead, uses live mailbox data.
        
        For historical records of when rules were created and past suspicious activity, use Get-HawkTenantInboxRuleHistory.

    .PARAMETER CSVPath
        A CSV file specifying a list of users to query.  
        Expected columns: DisplayName, PrimarySMTPAddress (minimum).

    .PARAMETER UserPrincipalName
        The UPN of the admin or account used to authenticate against Exchange Online.

    .OUTPUTS
        This function calls Get-HawkUserInboxRule and Get-HawkUserEmailForwarding. 
        For detailed information about the output, see their respective help documentation.

        File: Robust.log  
        Path: \  
        Description: The log file generated by Start-RobustCloudCommand, which is used to retrieve 
                     the rules and forwarding information from each mailbox.

    .EXAMPLE
        Start-HawkTenantInboxRules -UserPrincipalName userx@tenantdomain.onmicrosoft.com

        Retrieves the current inbox rules and forwarding for all mailboxes in the organization.

    .EXAMPLE
        Start-HawkTenantInboxRules -csvpath c:\temp\myusers.csv -UserPrincipalName admin@tenantdomain.onmicrosoft.com

        Retrieves the current inbox rules and forwarding for all mailboxes listed in myusers.csv.

    .LINK
        https://gallery.technet.microsoft.com/office/Start-RobustCloudCommand-69fb349e

    .NOTES
        - This function shows the current (live) rules and forwarding settings.
        - For historical data on when rules were created, refer to Get-HawkTenantInboxRuleHistory.
    #>


    param (
        [string]$CSVPath,
        [Parameter(Mandatory = $true)]
        [string]$UserPrincipalName
    )
    # Check if Hawk object exists and is fully initialized
    if (Test-HawkGlobalObject) {
        Initialize-HawkGlobalObject
    }


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
        0 { Out-LogFile "Starting full Tenant Search" -Action}
        1 { Write-Error -Message "User Stopped Cmdlet" -ErrorAction Stop }
    }

    # Get the exo PS session
    $exopssession = get-pssession | Where-Object { ($_.ConfigurationName -eq 'Microsoft.Exchange') -and ($_.State -eq 'Opened') }

    # Gather all of the mailboxes
    Out-LogFile "Getting all Mailboxes" -Action

    # If we don't have a value for csvpath then gather all users in the tenant
    if ([string]::IsNullOrEmpty($CSVPath)) {
        $AllMailboxes = Invoke-Command -Session $exopssession -ScriptBlock { Get-Recipient -RecipientTypeDetails UserMailbox -ResultSize Unlimited | Select-Object -Property DisplayName, PrimarySMTPAddress }
        $Allmailboxes | Out-MultipleFileType -FilePrefix "All_Mailboxes" -csv -json
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
    Out-LogFile ("Found " + $AllMailboxes.count + " Mailboxes") -Information

    # Path for robust log file
    # $RobustLog = Join-path $Hawk.FilePath "Robust.log"

    # Build the command we are going to need to run with Start-RobustCloudCommand
    # $cmd = "Start-RobustCloudCommand -UserPrincipalName " + $UserPrincipalName + " -logfile `$RobustLog -recipients `$AllMailboxes -scriptblock {Get-HawkUserInboxRule -UserPrincipalName `$input.PrimarySmtpAddress.tostring()}"
    $AllMailboxes | ForEach-Object {
        Start-RobustCloudCommand -UserPrincipalName $UserPrincipalName -LogFile $RobustLog -Recipients $_ -ScriptBlock {
            Get-HawkUserInboxRule -UserPrincipalName $_.PrimarySmtpAddress
        }
    }
    


    # Invoke our Start-Robust command to get all of the inbox rules
    Out-LogFile "===== Starting Robust Cloud Command to gather user inbox rules for all tenant users =====" -Action
    # Out-LogFile $cmd
    # Invoke-Expression $cmd

    # Build the command directly without using Invoke-Expression
    $AllMailboxes | ForEach-Object {
        Start-RobustCloudCommand -UserPrincipalName $UserPrincipalName -LogFile $RobustLog -Recipients $_ -ScriptBlock {
            Get-HawkUserInboxRule -UserPrincipalName $_.PrimarySmtpAddress
        }
    }

    Out-LogFile "Process Complete" -Information
}