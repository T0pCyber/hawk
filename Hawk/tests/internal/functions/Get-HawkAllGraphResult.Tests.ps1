Describe 'Get-HawkAllGraphResult' {

    Context 'When the Graph endpoint returns a single page' {
        BeforeAll {
            Mock -ModuleName Hawk Invoke-MgGraphRequest -MockWith {
                [PSCustomObject]@{ value = @([PSCustomObject]@{ id = '1' }, [PSCustomObject]@{ id = '2' }) }
            }
        }

        It 'Returns all items from the page' {
            $result = Get-HawkAllGraphResult -Uri 'https://graph.microsoft.com/v1.0/test'
            $result.Count | Should -Be 2
            $result[0].id | Should -Be '1'
        }

        It 'Calls Microsoft Graph exactly once when there is no nextLink' {
            $null = Get-HawkAllGraphResult -Uri 'https://graph.microsoft.com/v1.0/test'
            Should -Invoke -ModuleName Hawk -CommandName Invoke-MgGraphRequest -Times 1 -Exactly
        }
    }

    Context 'When the Graph endpoint is paged' {
        BeforeAll {
            Mock -ModuleName Hawk Invoke-MgGraphRequest -ParameterFilter { $Uri -eq 'https://graph.microsoft.com/v1.0/page1' } -MockWith {
                [PSCustomObject]@{ value = @([PSCustomObject]@{ id = 'a' }); '@odata.nextLink' = 'https://graph.microsoft.com/v1.0/page2' }
            }
            Mock -ModuleName Hawk Invoke-MgGraphRequest -ParameterFilter { $Uri -eq 'https://graph.microsoft.com/v1.0/page2' } -MockWith {
                [PSCustomObject]@{ value = @([PSCustomObject]@{ id = 'b' }) }
            }
        }

        It 'Follows nextLink and aggregates all pages' {
            $result = Get-HawkAllGraphResult -Uri 'https://graph.microsoft.com/v1.0/page1'
            $result.Count | Should -Be 2
            ($result.id -join ',') | Should -Be 'a,b'
        }
    }

    Context 'When the Graph request fails' {
        BeforeAll {
            Mock -ModuleName Hawk Invoke-MgGraphRequest -MockWith { throw 'Forbidden' }
            Mock -ModuleName Hawk Out-LogFile -MockWith { }
        }

        It 'Returns null so callers can degrade gracefully' {
            $result = Get-HawkAllGraphResult -Uri 'https://graph.microsoft.com/v1.0/test'
            $result | Should -BeNullOrEmpty
        }
    }
}
