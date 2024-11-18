# This file contains examples of both good and bad PowerShell code for testing PSScriptAnalyzer.
# To test the pre-commit hook or VS Code integration:
# 1. Uncomment the "Bad Code Examples" section
# 2. Try to commit the changes
# 3. Observe the PSScriptAnalyzer warnings/errors

#region Good Code Examples - These will pass PSScriptAnalyzer
function Test-GoodFunction {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true,
            HelpMessage = "Enter a string parameter")]
        [string]$Parameter
    )
    
    Write-Output $Parameter
}

function Test-ValidatedFunction {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true,
            HelpMessage = "Enter a file path to process")]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )
    
    $items = Get-ChildItem -Path $Path
    Write-Output $items
}
function Test-AdvancedFunction {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true,
            HelpMessage = "Enter a size in bytes")]
        [ValidateRange(0, [int]::MaxValue)]
        [int]$SizeInBytes
    )
    
    $result = [PSCustomObject]@{
        SizeInBytes = $SizeInBytes
        SizeInKB    = [math]::Round($SizeInBytes / 1KB, 2)
        SizeInMB    = [math]::Round($SizeInBytes / 1MB, 2)
    }
    
    Write-Output $result
}

#endregion

#region Bad Code Examples - Uncomment to test PSScriptAnalyzer
# NOTE: The following code is intentionally written with issues to demonstrate PSScriptAnalyzer rules

<#
# Bad function - Multiple issues
function test-badfunction {    # Wrong capitalization
    param([string]$param1)    # Missing CmdletBinding
    
    $Global:badVariable = $param1    # Using global variable
    
    write-output $badVariable        # Incorrect capitalization
    
} # Trailing whitespace after this line    

# More issues
$unusedVariable = "test"    # Variable declared but never used

# Bad parameter validation
function Test-BadValidation {
    param(
        [string]
        $Parameter    # Missing mandatory and help message
    )
    
    Write-host $Parameter    # Write-Host instead of Write-Output
}

# Aliases and positional parameters
dir C:\ | where {$_.Length -gt 1000}    # Using aliases instead of full cmdlet names
#>
#endregion

#region Testing Instructions
<#
To test PSScriptAnalyzer integration:

1. VS Code Testing:
   - Uncomment the "Bad Code Examples" region
   - Observe the squiggly lines indicating issues
   - Hover over the lines to see the specific rule violations

2. Pre-commit Hook Testing:
   - Uncomment the "Bad Code Examples" region
   - Stage the changes: git add Test-PreCommitHook.ps1
   - Try to commit: git commit -m "test: Testing PSScriptAnalyzer"
   - The commit should fail with PSScriptAnalyzer warnings

3. Remember to comment out the bad code when done testing!

Common Issues Demonstrated:
- PSAvoidGlobalVars
- PSAvoidUsingCmdletAliases
- PSAvoidUsingWriteHost
- PSUseDeclaredVarsMoreThanAssignments
- PSUseConsistentWhitespace
- PSUseCmdletCorrectly
#>
#endregion

