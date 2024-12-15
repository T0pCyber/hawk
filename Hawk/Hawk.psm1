$script:ModuleRoot = $PSScriptRoot
$script:ModuleVersion = (Import-PowerShellDataFile -Path "$($script:ModuleRoot)\Hawk.psd1").ModuleVersion

# Detect whether at some level dotsourcing was enforced
$script:doDotSource = Get-PSFConfigValue -FullName Hawk.Import.DoDotSource -Fallback $false
if ($Hawk_dotsourcemodule) { $script:doDotSource = $true }

<#
Note on Resolve-Path:
All paths are sent through Resolve-Path/Resolve-PSFPath in order to convert them to the correct path separator.
Resolve-Path can only be used for paths that already exist, Resolve-PSFPath can accept that the last leaf may not exist.
#>

# Detect whether loading individual module files was enforced
$importIndividualFiles = Get-PSFConfigValue -FullName Hawk.Import.IndividualFiles -Fallback $false
if ($Hawk_importIndividualFiles) { $importIndividualFiles = $true }
if (Test-Path (Resolve-PSFPath -Path "$($script:ModuleRoot)\..\.git" -SingleItem -NewChild)) { $importIndividualFiles = $true }
if ("<was not compiled>" -eq '<was not compiled>') { $importIndividualFiles = $true }

function Import-ModuleFile {
    <#
        .SYNOPSIS
            Loads files into the module on module import.

        .DESCRIPTION
            This helper function is used during module initialization.
            It ensures PowerShell script files are imported safely.

        .PARAMETER Path
            The path to the file to load.

        .EXAMPLE
            PS C:\> . Import-ModuleFile -Path $function.FullName
    #>
    [CmdletBinding()]
    Param (
        [string]
        $Path
    )

    if (-not (Test-Path $Path)) {
        Write-Warning "Skipping file: $Path does not exist."
        return
    }

    $resolvedPath = $ExecutionContext.SessionState.Path.GetResolvedPSPathFromPSPath($Path).ProviderPath
    Write-Host "Importing file: $resolvedPath"
    if ($doDotSource) {
        . $resolvedPath
    }
    else {
        $scriptContent = [io.file]::ReadAllText($resolvedPath)
        $ExecutionContext.InvokeCommand.InvokeScript($false, ([scriptblock]::Create($scriptContent)), $null, $null)
    }
}

#region Load individual files
if ($importIndividualFiles) {
    Write-Host "Starting individual file import process..."

    # Execute Preimport actions
    foreach ($path in (& "$ModuleRoot\internal\scripts\preimport.ps1")) {
        if (-not (Test-Path $path)) {
            Write-Warning "Preimport script not found: $path"
            continue
        }
        . Import-ModuleFile -Path $path
    }

    # Import all internal functions
    foreach ($function in (Get-ChildItem "$ModuleRoot\internal\functions" -Filter "*.ps1" -Recurse -ErrorAction Ignore)) {
        if (-not (Test-Path $function.FullName)) {
            Write-Warning "Skipping invalid file: $($function.FullName)"
            continue
        }
        . Import-ModuleFile -Path $function.FullName
    }

    # Import all public functions
    foreach ($function in (Get-ChildItem "$ModuleRoot\functions" -Filter "*.ps1" -Recurse -ErrorAction Ignore)) {
        if (-not (Test-Path $function.FullName)) {
            Write-Warning "Skipping invalid file: $($function.FullName)"
            continue
        }
        . Import-ModuleFile -Path $function.FullName
    }

    # Execute Postimport actions
    foreach ($path in (& "$ModuleRoot\internal\scripts\postimport.ps1")) {
        if (-not (Test-Path $path)) {
            Write-Warning "Postimport script not found: $path"
            continue
        }
        . Import-ModuleFile -Path $path
    }

    Write-Host "Individual file import process completed."
    return
}
#endregion Load individual files

#region Load compiled code
"<compile code into here>"
#endregion Load compiled code
