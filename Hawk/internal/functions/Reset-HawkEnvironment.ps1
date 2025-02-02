Function Reset-HawkEnvironment {
    <#
    .SYNOPSIS
        Resets all Hawk-related variables to allow for a fresh instance.

    .DESCRIPTION
        This function removes all global variables used by Hawk, including the main Hawk object,
        IP location cache, and Microsoft IP list. This allows you to start fresh with Hawk
        without needing to close and reopen your PowerShell window.

        Variables removed:
        - $Hawk (Main configuration object)
        - $IPlocationCache (IP geolocation cache)
        - $MSFTIPList (Microsoft IP address list)
        - $HawkAppData (Application data)

    .PARAMETER Confirm
        Prompts for confirmation before executing the command. 
        Specify -Confirm:$false to suppress confirmation prompts.

    .PARAMETER WhatIf
        Shows what would happen if the command runs.
        The command is not executed.

    .EXAMPLE
        Reset-HawkEnvironment
        
        Removes all Hawk-related variables and confirms when ready for a fresh start.

    .EXAMPLE
        Reset-HawkEnvironment -Verbose
        
        Removes all Hawk-related variables with detailed progress messages.

    .EXAMPLE
        Reset-HawkEnvironment -WhatIf
        
        Shows what variables would be removed without actually removing them.

    .NOTES
        Author: Jonathan Butler
        Version: 1.0
        Last Modified: 2025-01-20

        This function should be used when you need to start a fresh Hawk investigation
        without closing your PowerShell session.
    #>
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
    param()

    # Store original preference
    $originalInformationPreference = $InformationPreference
    $InformationPreference = 'Continue'

    Write-Information "Beginning Hawk environment cleanup..."

    # List of known Hawk-related variables to remove
    $hawkVariables = @(
        'Hawk',                  # Main Hawk configuration object
        'IPlocationCache',       # IP geolocation cache
        'MSFTIPList',           # Microsoft IP address list
        'HawkAppData'           # Hawk application data
    )

    foreach ($varName in $hawkVariables) {
        if (Get-Variable -Name $varName -ErrorAction SilentlyContinue) {
            try {
                if ($PSCmdlet.ShouldProcess("Variable $varName", "Remove")) {
                    Remove-Variable -Name $varName -Scope Global -Force -ErrorAction Stop
                    Write-Information "Successfully removed `$$varName"
                }
            }
            catch {
                Write-Warning "Failed to remove `$$varName : $_"
            }
        }
        else {
            Write-Information "`$$varName was not present"
        }
    }

    # Clear any PSFramework configuration cache
    if ($PSCmdlet.ShouldProcess("PSFramework cache", "Clear")) {
        if (Get-Command -Name 'Clear-PSFResultCache' -ErrorAction SilentlyContinue) {
            Clear-PSFResultCache
            Write-Information "Cleared PSFramework result cache"
        }
    }

    Write-Information "`nHawk environment has been reset!"
    Write-Information "You can now run Initialize-HawkGlobalObject for a fresh start.`n"

    # Restore original preference
    $InformationPreference = $originalInformationPreference
}