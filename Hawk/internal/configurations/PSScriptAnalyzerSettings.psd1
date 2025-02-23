# To use the PowerShell Script Analyzer, use the following command.
# Invoke-ScriptAnalyzer -Settings PSScriptAnalyzerSettings.psd1 -Path MyScript.ps1
#
# Reference: https://learn.microsoft.com/powershell/utility-modules/psscriptanalyzer/overview?view=ps-modules

@{
    IncludeDefaultRules = $true
    Severity = @('Error', 'Warning', 'Information')
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
    Rules = @{

        PSAvoidLongLines = @{
            Enable = $false
            MaximumLineLength = 120
        }

        PSAvoidSemicolonsAsLineTerminators = @{
            Enable = $true
        }

        PSPlaceOpenBrace = @{
            Enable = $true
            OnSameLine = $false
            NewLineAfter = $true
            IgnoreOneLineBlock = $true
        }

        PSProvideCommentHelp = @{
            Enable = $false
            ExportedOnly = $false
            BlockComment = $true
            VSCodeSnippetCorrection = $true
            Placement = "before"
        }

        PSUseCompatibleSyntax = @{
            Enable = $true
            TargetVersions = @(
                "7.0",
                "6.0",
                "5.1"
            )
        }

        PSUseCorrectCasing = @{ Enable = $true }

        PSUseConsistentIndentation = @{
            Enable = $true
            IndentationSize = 4
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
            Kind = 'space'
        }

        PSUseConsistentWhitespace = @{
            Enable = $true
            CheckInnerBrace = $true
            CheckOpenBrace = $true
            CheckOpenParen = $true
            CheckOperator = $true
            CheckPipe = $true
            CheckPipeForRedundantWhitespace = $false
            CheckSeparator = $true
            CheckParameter = $true
            IgnoreAssignmentOperatorInsideHashTable = $false
        }
    }
}