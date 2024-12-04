# Load Pester module if not already loaded
Import-Module -Name Pester -ErrorAction Stop

# Log function for consistent output
function Log {
    param(
        [string]$Message,
        [string]$Level = "Info"
    )
    $timestamp = Get-Date -Format "HH:mm:ss"
    Write-Output "[$timestamp][$Level] $Message"
}

# Start of test execution
Log "Starting Tests"

# Define the tests directory
$testDirectory = "$PSScriptRoot"

# Get all test files in the directory, excluding specific ones
$testFiles = Get-ChildItem -Path $testDirectory -Recurse -Include *.Tests.ps1 |
    Where-Object { $_.Name -notin @('pester.ps1', 'Run-PesterTests.ps1') }

# Ensure we found test files
if (-not $testFiles) {
    Log "No test files found to execute." "Error"
    exit 1
}

# Loop through each test file
foreach ($testFile in $testFiles) {
    Log "Executing $($testFile.FullName)" "Info"
    try {
        # Run tests with minimal output
        Invoke-Pester -Path $testFile.FullName -Output Minimal -PassThru | Out-Null
    } catch {
        Log "Error running $($testFile.FullName): $_" "Error"
    }
}

Log "All tests executed successfully!" "Success"
