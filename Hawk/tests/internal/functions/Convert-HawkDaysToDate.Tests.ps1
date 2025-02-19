Describe 'Convert-HawkDaysToDate' {

    Context 'When converting valid days to dates' {
        BeforeEach {
            # Get current date in UTC for consistent testing
            $script:currentDate = (Get-Date).ToUniversalTime().Date
        }

        It 'Should return correct dates for 30 days lookback' {
            # Arrange
            $expectedStartDate = $script:currentDate.AddDays(-30)
            $expectedEndDate = $script:currentDate.AddDays(1)

            # Act
            $result = Convert-HawkDaysToDate -DaysToLookBack 30

            # Assert
            $result.StartDate | Should -Be $expectedStartDate
            $result.EndDate | Should -Be $expectedEndDate
        }

        It 'Should return correct dates for 1 day lookback' {
            # Arrange
            $expectedStartDate = $script:currentDate.AddDays(-1)
            $expectedEndDate = $script:currentDate.AddDays(1)

            # Act
            $result = Convert-HawkDaysToDate -DaysToLookBack 1

            # Assert
            $result.StartDate | Should -Be $expectedStartDate
            $result.EndDate | Should -Be $expectedEndDate
        }

        It 'Should return correct dates for 365 day lookback' {
            # Arrange
            $expectedStartDate = $script:currentDate.AddDays(-365)
            $expectedEndDate = $script:currentDate.AddDays(1)

            # Act
            $result = Convert-HawkDaysToDate -DaysToLookBack 365

            # Assert
            $result.StartDate | Should -Be $expectedStartDate
            $result.EndDate | Should -Be $expectedEndDate
        }
    }

    Context 'When verifying date properties' {
        It 'Should return dates in UTC format' {
            # Act
            $result = Convert-HawkDaysToDate -DaysToLookBack 30

            # Assert
            $result.StartDate.Kind | Should -Be 'Utc'
            $result.EndDate.Kind | Should -Be 'Utc'
        }

        It 'Should return dates at midnight' {
            # Act
            $result = Convert-HawkDaysToDate -DaysToLookBack 30

            # Assert
            $result.StartDate.TimeOfDay | Should -Be ([TimeSpan]::Zero)
            $result.EndDate.TimeOfDay | Should -Be ([TimeSpan]::Zero)
        }

        It 'Should return EndDate exactly one day after current date' {
            # Arrange
            $currentDate = (Get-Date).ToUniversalTime().Date

            # Act
            $result = Convert-HawkDaysToDate -DaysToLookBack 30

            # Assert
            $daysDifference = ($result.EndDate - $currentDate).Days
            $daysDifference | Should -Be 1
        }
    }

    Context 'When verifying return object structure' {
        It 'Should return a PSCustomObject with expected properties' {
            # Act
            $result = Convert-HawkDaysToDate -DaysToLookBack 30

            # Assert
            $result | Should -BeOfType [PSCustomObject]
            $result.PSObject.Properties.Name | Should -Contain 'StartDate'
            $result.PSObject.Properties.Name | Should -Contain 'EndDate'
        }

        It 'Should return DateTime objects for both dates' {
            # Act
            $result = Convert-HawkDaysToDate -DaysToLookBack 30

            # Assert
            $result.StartDate | Should -BeOfType [DateTime]
            $result.EndDate | Should -BeOfType [DateTime]
        }
    }
}