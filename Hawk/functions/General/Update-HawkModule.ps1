Function Update-HawkModule {
    <#
    .SYNOPSIS
       Hawk upgrade check.
    
    .DESCRIPTION
       Hawk upgrade check. Checks the PowerShell Gallery for newer versions of the Hawk module and handles the update process, including elevation of privileges if needed.
    
    .PARAMETER ElevatedUpdate
       Switch parameter indicating the function is running in an elevated context.
    
    .PARAMETER WhatIf
       Shows what would happen if the command runs. The command is not run.
       
    .PARAMETER Confirm 
       Prompts you for confirmation before running the command.
    
    .EXAMPLE
       Update-HawkModule
       
       Checks for update to Hawk Module on PowerShell Gallery.
    
    .NOTES
       Requires elevation to Administrator rights to perform the update.
    #>
       [CmdletBinding(SupportsShouldProcess)]
       param
       (
           [switch]$ElevatedUpdate
       )
    
       # If ElevatedUpdate is true then we are running from a forced elevation and we just need to run without prompting
       if ($ElevatedUpdate) {
           # Set upgrade to true
           $Upgrade = $true
       }
       else {
    
           # See if we can do an upgrade check
           if ($null -eq (Get-Command Find-Module)) { }
    
           # If we can then look for an updated version of the module
           else {
               Out-LogFile "Checking for latest version online" -Action
               $onlineversion = Find-Module -name Hawk -erroraction silentlycontinue
               $Localversion = (Get-Module Hawk | Sort-Object -Property Version -Descending)[0]
               Out-LogFile ("Found Version " + $onlineversion.version + " Online") -Information

               if ($null -eq $onlineversion){
                   Out-LogFile "[ERROR] - Unable to check Hawk version in Gallery" -isError 
               }
               elseif (([version]$onlineversion.version) -gt ([version]$localversion.version)) {
                   Out-LogFile "New version of Hawk module found online" -Information
                   Out-LogFile ("Local Version: " + $localversion.version + " Online Version: " + $onlineversion.version) -Information
    
                   # Prompt the user to upgrade or not
                   $title = "Upgrade version"
                   $message = "A Newer version of the Hawk Module has been found Online. `nUpgrade to latest version?"
                   $Yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Stops the function and provides directions for upgrading."
                   $No = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Continues running current function"
                   $options = [System.Management.Automation.Host.ChoiceDescription[]]($Yes, $No)
                   $result = $host.ui.PromptForChoice($title, $message, $options, 0)
    
                   # Check to see what the user choose
                   switch ($result) {
                       0 { $Upgrade = $true; Send-AIEvent -Event Upgrade -Properties @{"Upgrade" = "True" }
                       }
                       1 { $Upgrade = $false; Send-AIEvent -Event Upgrade -Properties @{"Upgrade" = "False" }
                       }
                   }
               }
               # If the versions match then we don't need to upgrade
               else {
                   Out-LogFile "Latest Version Installed" -Information
               }
           }
       }
    
       # If we determined that we want to do an upgrade make the needed checks and do it
       if ($Upgrade) {
           # Determine if we have an elevated powershell prompt
           If (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
               # Update the module
               if ($PSCmdlet.ShouldProcess("Hawk Module", "Update module")) {
                   Out-LogFile "Downloading Updated Hawk Module" -Action
                   Update-Module Hawk -Force
                   Out-LogFile "Update Finished" -Action
                   Start-Sleep 3
    
                   # If Elevated update then this prompt was created by the Update-HawkModule function and we can close it out otherwise leave it up
                   if ($ElevatedUpdate) { exit }
    
                   # If we didn't elevate then we are running in the admin prompt and we need to import the new hawk module
                   else {
                       Out-LogFile "Starting new PowerShell Window with the updated Hawk Module loaded" -Action
    
                       # We can't load a new copy of the same module from inside the module so we have to start a new window
                       Start-Process powershell.exe -ArgumentList "-noexit -Command Import-Module Hawk -force" -Verb RunAs
                       Out-LogFile "Updated Hawk Module loaded in New PowerShell Window. Please Close this Window." -Notice
                       break
                   }
               }
           }
           # If we are not running as admin we need to start an admin prompt
           else {
               # Relaunch as an elevated process:
               Out-LogFile "Starting Elevated Prompt" -Action
               Start-Process powershell.exe -ArgumentList "-noexit -Command Import-Module Hawk;Update-HawkModule -ElevatedUpdate" -Verb RunAs -Wait
    
               Out-LogFile "Starting new PowerShell Window with the updated Hawk Module loaded" -Action
    
               # We can't load a new copy of the same module from inside the module so we have to start a new window
               Start-Process powershell.exe -ArgumentList "-noexit -Command Import-Module Hawk -force"
               Out-LogFile "Updated Hawk Module loaded in New PowerShell Window. Please Close this Window." -Notice
               break
           }
       }
       # Since upgrade is false we log and continue
       else {
           Out-LogFile "Skipping Upgrade" -Action
       }
    }