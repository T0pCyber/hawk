$ErrorActionPreference = 'Stop'
$settings = Join-Path (Get-Location) 'Hawk/internal/configurations/PSScriptAnalyzerSettings.psd1'

# Define the list of files to exclude
$excludedFiles = @(
    'none'
)

$files = git diff --cached --name-only --diff-filter=AM | Where-Object { $_ -match '\.(ps1|psm1|psd1)$' }
$hasErrors = $false

foreach ($file in $files) {
    if ($excludedFiles -notcontains $file) {
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