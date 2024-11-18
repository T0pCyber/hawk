# This is a test file to verify PSScriptAnalyzer pre-commit hooks

# Good function - should pass
function Test-GoodFunction {
    [CmdletBinding()]
    param (
        [string]$Parameter
    )
    
    Write-Output $Parameter
}

function Test-FixedFunction {
    [CmdletBinding()]
    param(
        [string]$Parameter
    )
    
    $localVariable = $Parameter    # Using local variable instead of global
    Write-Output $localVariable    # Using consistent capitalization
}