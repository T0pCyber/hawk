if ($MyInvocation.ScriptName -eq (Join-Path $PSScriptRoot 'Invoke-PowerShellScriptAnalyzer.ps1')) {
    $excludedFiles = @(
        'C:\Users\xxbut\code\hawk\Hawk\tests\general\Test-PreCommitHook.ps1'
    )

    $files = git diff --cached --name-only --diff-filter=AM | Where-Object { $_ -match '\.(ps1|psm1|psd1)$' }
    $hasErrors = $false

    foreach ($file in $files) {
        if ($excludedFiles -contains $file) {
            Write-Output "Skipping analysis for excluded file: $file"
        }
        else {
            Write-Output "Analyzing $file..."
            $results = Invoke-ScriptAnalyzer -Path $file -Settings $settings
            if ($results) {
                $results | Format-Table -AutoSize
                $hasErrors = $true
            }
        }
    }

    if ($hasErrors) {
        Write-Output "PSScriptAnalyzer found errors. Exiting with error code 1."
        exit 1
    }
    else {
        Write-Output "No PSScriptAnalyzer issues found. Exiting with code 0."
        exit 0
    }
}
else {
    # Original script content
}