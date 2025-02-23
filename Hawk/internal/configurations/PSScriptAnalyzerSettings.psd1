@{
    # Rules to be excluded from analysis
    ExcludeRules = @(
        # These are both excluded because they were hardcoded in the Hawk PSScriptAnalyzer.Tests originally.
        # It is assumed this was done with good reason.
        'PSAvoidTrailingWhitespace'
        'PSShouldProcess'
        # Exclude this as old test rules use Global Vars, will need to fix old tests and re-include this rule
        'PSAvoidGlobalVars'
        'PSUseDeclaredVarsMoreThanAssignments' 
        # Exclude this to allow the use of Write-Host
        'PSAvoidUsingWriteHost'
        # Exclude this to allow plural nouns in cmdlet names
        'PSUseSingularNouns'
        # Exclude this to allow test assignments to $PSBoundParameters for mocking
        'PSAvoidAssignmentToAutomaticVariable'
    )
}