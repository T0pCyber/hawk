Function Get-HawkUserPath {
    <#
    .SYNOPSIS
        Gets the output folder path for a specific user in Hawk
    .DESCRIPTION
        Creates and returns the full path to a user's output folder within the Hawk
        file structure. Creates the folder if it doesn't exist.
    .PARAMETER User
        The UserPrincipalName of the user to create/get path for
    .EXAMPLE
        Get-HawkUserPath -User "user@contoso.com"

        Returns the full path to the user's output folder and creates it if it doesn't exist
    .OUTPUTS
        System.String
        Returns the full path to the user's output folder
    .NOTES
        Internal function used by Hawk cmdlets to manage user-specific output folders
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$User
    )

    # Check if Hawk global object exists
    if ([string]::IsNullOrEmpty($Hawk.FilePath)) {
        Initialize-HawkGlobalObject
    }

    # Join the Hawk filepath with the user's UPN for the output folder
    $userPath = Join-Path -Path $Hawk.FilePath -ChildPath $User

    # Create directory if it doesn't exist
    if (-not (Test-Path -Path $userPath)) {
        Out-LogFile "Making output directory for user $userPath" -Action
        New-Item -Path $userPath -ItemType Directory -Force | Out-Null
    }

    return $userPath
}