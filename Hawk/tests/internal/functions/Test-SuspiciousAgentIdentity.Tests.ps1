Describe 'Test-SuspiciousAgentIdentity' {

    Context 'When the agent has no owner' {
        It 'Flags the agent as suspicious with an orphaned reason' {
            $agent = [PSCustomObject]@{ Owners = $null; HasPasswordSecret = $false; CreatedDateTime = $null; AccountEnabled = $true }
            $reasons = @()
            $result = Test-SuspiciousAgentIdentity -Agent $agent -Reasons ([ref]$reasons)
            $result | Should -BeTrue
            ($reasons -join ' ') | Should -BeLike '*no owner*'
        }
    }

    Context 'When the agent uses password-secret credentials' {
        It 'Flags the agent as suspicious' {
            $agent = [PSCustomObject]@{ Owners = 'owner@contoso.com'; HasPasswordSecret = $true; CreatedDateTime = $null; AccountEnabled = $true }
            $reasons = @()
            $result = Test-SuspiciousAgentIdentity -Agent $agent -Reasons ([ref]$reasons)
            $result | Should -BeTrue
            ($reasons -join ' ') | Should -BeLike '*password-secret*'
        }
    }

    Context 'When the agent is disabled' {
        It 'Flags the agent as suspicious' {
            $agent = [PSCustomObject]@{ Owners = 'owner@contoso.com'; HasPasswordSecret = $false; CreatedDateTime = $null; AccountEnabled = $false }
            $reasons = @()
            $result = Test-SuspiciousAgentIdentity -Agent $agent -Reasons ([ref]$reasons)
            $result | Should -BeTrue
            ($reasons -join ' ') | Should -BeLike '*disabled*'
        }
    }

    Context 'When an already-flagged agent was also created in the investigation window' {
        BeforeAll {
            $global:Hawk = [PSCustomObject]@{ StartDate = (Get-Date).AddDays(-10); EndDate = (Get-Date).AddDays(1) }
        }
        AfterAll { Remove-Variable -Name Hawk -Scope Global -ErrorAction SilentlyContinue }
        It 'Appends the creation-window note as context to the real reason' {
            $agent = [PSCustomObject]@{ Owners = $null; HasPasswordSecret = $false; CreatedDateTime = (Get-Date).AddDays(-2); AccountEnabled = $true }
            $reasons = @()
            $result = Test-SuspiciousAgentIdentity -Agent $agent -Reasons ([ref]$reasons)
            $result | Should -BeTrue
            ($reasons -join ' ') | Should -BeLike '*no owner*'
            ($reasons -join ' ') | Should -BeLike '*investigation window*'
        }
    }

    Context 'When an agent is only recent but otherwise well-governed' {
        BeforeAll {
            $global:Hawk = [PSCustomObject]@{ StartDate = (Get-Date).AddDays(-10); EndDate = (Get-Date).AddDays(1) }
        }
        AfterAll { Remove-Variable -Name Hawk -Scope Global -ErrorAction SilentlyContinue }
        It 'Does not flag the agent on recency alone' {
            $agent = [PSCustomObject]@{ Owners = 'owner@contoso.com'; HasPasswordSecret = $false; CreatedDateTime = (Get-Date).AddDays(-2); AccountEnabled = $true }
            $reasons = @()
            $result = Test-SuspiciousAgentIdentity -Agent $agent -Reasons ([ref]$reasons)
            $result | Should -BeFalse
            $reasons | Should -BeNullOrEmpty
        }
    }

    Context 'When the agent is well-governed and older' {
        BeforeAll {
            $global:Hawk = [PSCustomObject]@{ StartDate = (Get-Date).AddDays(-10); EndDate = (Get-Date).AddDays(1) }
        }
        AfterAll { Remove-Variable -Name Hawk -Scope Global -ErrorAction SilentlyContinue }
        It 'Does not flag the agent' {
            $agent = [PSCustomObject]@{ Owners = 'owner@contoso.com'; HasPasswordSecret = $false; CreatedDateTime = (Get-Date).AddDays(-365); AccountEnabled = $true }
            $reasons = @()
            $result = Test-SuspiciousAgentIdentity -Agent $agent -Reasons ([ref]$reasons)
            $result | Should -BeFalse
            $reasons | Should -BeNullOrEmpty
        }
    }
}
