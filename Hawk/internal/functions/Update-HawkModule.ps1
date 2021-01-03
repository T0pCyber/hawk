<#
.SYNOPSIS
    Hawk upgrade check
.DESCRIPTION
    Hawk upgrade check
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
Function Update-HawkModule {
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
            Write-Output "Checking for latest version online"
            $onlineversion = Find-Module -name Hawk -erroraction silentlycontinue
            $Localversion = (Get-Module Hawk | Sort-Object -Property Version -Descending)[0]
            Write-Output ("Found Version " + $onlineversion.version + " Online")

            if ($null -eq $onlineversion){
                Write-Output "[ERROR] - Unable to check Hawk version in Gallery"
            }
            elseif (([version]$onlineversion.version) -gt ([version]$localversion.version)) {
                Write-Output "New version of Hawk module found online"
                Write-Output ("Local Version: " + $localversion.version + " Online Version: " + $onlineversion.version)

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
                Write-Output "Latest Version Installed"
            }
        }
    }

    # If we determined that we want to do an upgrade make the needed checks and do it
    if ($Upgrade) {
        # Determine if we have an elevated powershell prompt
        If (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            # Update the module
            Write-Output "Downloading Updated Hawk Module"
            Update-Module Hawk -Force
            Write-Output "Update Finished"
            Start-Sleep 3

            # If Elevated update then this prompt was created by the Update-HawkModule function and we can close it out otherwise leave it up
            if ($ElevatedUpdate) { exit }

            # If we didn't elevate then we are running in the admin prompt and we need to import the new hawk module
            else {
                Write-Output "Starting new PowerShell Window with the updated Hawk Module loaded"

                # We can't load a new copy of the same module from inside the module so we have to start a new window
                Start-Process powershell.exe -ArgumentList "-noexit -Command Import-Module Hawk -force" -Verb RunAs
                Write-Warning "Updated Hawk Module loaded in New PowerShell Window. `nPlease Close this Window."
                break
            }

        }
        # If we are not running as admin we need to start an admin prompt
        else {
            # Relaunch as an elevated process:
            Write-Output "Starting Elevated Prompt"
            Start-Process powershell.exe -ArgumentList "-noexit -Command Import-Module Hawk;Update-HawkModule -ElevatedUpdate" -Verb RunAs -Wait

            Write-Output "Starting new PowerShell Window with the updated Hawk Module loaded"

            # We can't load a new copy of the same module from inside the module so we have to start a new window
            Start-Process powershell.exe -ArgumentList "-noexit -Command Import-Module Hawk -force"
            Write-Warning "Updated Hawk Module loaded in New PowerShell Window. `nPlease Close this Window."
            break
        }
    }
    # Since upgrade is false we log and continue
    else {
        Write-Output "Skipping Upgrade"
    }
}		