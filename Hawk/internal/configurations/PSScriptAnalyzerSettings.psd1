@{
    # Rules to be excluded from analysis
    ExcludeRules = @(
        # These are both excluded because they were hardcoded in the Hawk PSScriptAnalyzer.Tests originally.
        # It is assumed this was done with good reason.
        'PSAvoidTrailingWhitespace'
        'PSShouldProcess'
    )
}