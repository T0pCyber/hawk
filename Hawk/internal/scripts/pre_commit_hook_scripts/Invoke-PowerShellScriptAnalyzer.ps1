$ErrorActionPreference = 'Stop'

# Import the module
Import-Module PSScriptAnalyzer

$settings = Join-Path (Get-Location) 'Hawk/internal/configurations/PSScriptAnalyzerSettings.psd1'

# Define the list of files to exclude - including the analyzer script itself
$excludedFiles = @(
    'Invoke-PowerShellScriptAnalyzer.ps1',
    'pre_commit_hook_scripts/Invoke-PowerShellScriptAnalyzer.ps1',
    'internal/scripts/pre_commit_hook_scripts/Invoke-PowerShellScriptAnalyzer.ps1'
)

$files = git diff --cached --name-only --diff-filter=AM | Where-Object { $_ -match '\.(ps1|psm1|psd1)$' }
$hasErrors = $false

foreach ($file in $files) {
    # Check if file is in excluded list using any variation of the path
    $isExcluded = $false
    foreach ($excludedFile in $excludedFiles) {
        if ($file -match [regex]::Escape($excludedFile)) {
            $isExcluded = $true
            break
        }
    }

    if (-not $isExcluded) {
        Write-Output "Analyzing $file..."
        $results = Invoke-ScriptAnalyzer -Path $file -Settings $settings
        if ($results) {
            $results | Format-Table -AutoSize
            $hasErrors = $true
        }
    }
    else {
        Write-Output "Skipping analysis for excluded file: $file"
    }
}

if ($hasErrors) { exit 1 }
exit 0