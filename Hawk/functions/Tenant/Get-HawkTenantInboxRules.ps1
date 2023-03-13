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

.PARAMETER UserPrincipalName
    The UPN of the user that will authenticate against Exchange Online.

.OUTPUTS
    See Help for Get-HawkUserInboxRule for inbox rule output
    See Help for Get-HawkUserEmailForwarding for email forwarding output

    File: Robust.log
    Path: \
    Description: Logfile for Start-RobustCloudCommand

.EXAMPLE
    Start-HawkTenantInboxRules -UserPrincipalName userx@tenantdomain.onmicrosoft.com

    Runs Get-HawkUserInboxRule and Get-HawkUserEmailForwarding against all mailboxes in the org. The UserPrincipalName
    is the Admin/User who is running the cmdlet.

.EXAMPLE
    Start-HawkTenantInboxRules -csvpath c:\temp\myusers.csv

    Runs Get-HawkUserInboxRule and Get-HawkUserEmailForwarding against all mailboxes listed in myusers.csv.The UserPrincipalName
    is the Admin/User who is running the cmdlet.

.LINK
    https://gallery.technet.microsoft.com/office/Start-RobustCloudCommand-69fb349e
#>

    param (
        [string]$CSVPath,
        [Parameter(Mandatory = $true)]
        [string]$UserPrincipalName
    )

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
    Out-LogFile ("Found " + $AllMailboxes.count + " Mailboxes")

    # Path for robust log file
    $RobustLog = Join-path $Hawk.FilePath "Robust.log"

    # Build the command we are going to need to run with Start-RobustCloudCommand
    $cmd = "Start-RobustCloudCommand -UserPrincipalName " + $UserPrincipalName + " -logfile `$RobustLog -recipients `$AllMailboxes -scriptblock {Get-HawkUserInboxRule -UserPrincipalName `$input.PrimarySmtpAddress.tostring()}"

    # Invoke our Start-Robust command to get all of the inbox rules
    Out-LogFile "===== Starting Robust Cloud Command to gather user inbox rules for all tenant users ====="
    Out-LogFile $cmd
    Invoke-Expression $cmd

    Out-LogFile "Process Complete"
}