<#
.SYNOPSIS
    Runs PSScriptAnalyzer on changed PowerShell files in a GitHub workflow.
.DESCRIPTION
    This script is designed to be used in a GitHub Actions workflow to analyze changed PowerShell files
    using PSScriptAnalyzer. It reads the list of changed files from a file, analyzes them using the
    provided settings file, and outputs the results.
.PARAMETER SettingsPath
    The path to the PSScriptAnalyzer settings file.
.PARAMETER ChangedFiles
    The path to the file containing the list of changed PowerShell files.
.EXAMPLE
    Invoke-GitHubPSScriptAnalyzer -SettingsPath 'Hawk/internal/configurations/PSScriptAnalyzerSettings.psd1' -ChangedFiles "$env:GITHUB_WORKSPACE/changed_files.txt"
#>
function Invoke-GitHubPSScriptAnalyzer {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$SettingsPath,
        [Parameter(Mandatory = $true)]
        [string]$ChangedFiles
    )

    Write-Output "Using settings file: $SettingsPath"
    if (-not (Test-Path $SettingsPath)) {
        Write-Error "PSScriptAnalyzer settings file not found at: $SettingsPath"
        exit 1
    }

    $changedFiles = Get-Content -Path $ChangedFiles
    if (-not $changedFiles) {
        Write-Output "No PowerShell files were changed"
        $null > (Join-Path $env:GITHUB_WORKSPACE 'psscriptanalyzer-results.txt')
        exit 0
    }

    $results = @()
    foreach ($file in $changedFiles) {
        $fullPath = Join-Path $env:GITHUB_WORKSPACE $file
        if (Test-Path $fullPath) {
            Write-Output "Analyzing $fullPath"
            $fileResults = Invoke-ScriptAnalyzer -Path $fullPath -Settings $SettingsPath
            if ($fileResults) {
                $results += $fileResults
            }
        }
    }

    if ($results) {
        Write-Output "Found $($results.Count) issues in changed files:"
        $results | Format-Table -AutoSize | Out-String | Write-Output
        $results | Format-Table -AutoSize | Out-File (Join-Path $env:GITHUB_WORKSPACE 'psscriptanalyzer-results.txt')
        exit 1
    }
    else {
        Write-Output "No PSScriptAnalyzer issues found in changed files"
        $null > (Join-Path $env:GITHUB_WORKSPACE 'psscriptanalyzer-results.txt')
        exit 0
    }
}