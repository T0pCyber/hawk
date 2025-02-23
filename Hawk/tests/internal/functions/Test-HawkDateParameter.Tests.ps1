Describe 'Test-HawkDateParameter' {
    BeforeAll {
        # Mock Stop-PSFFunction to intercept and throw the error message directly
        Mock -ModuleName Hawk Stop-PSFFunction {
            param($Message)
            throw $Message
        }
    }

    Context 'Parameter combination validation' {
        It 'Should throw when neither StartDate nor DaysToLookBack is provided' {
            # Arrange
            $PSBoundParameters = @{}

            # Act & Assert
            { Test-HawkDateParameter -PSBoundParameters $PSBoundParameters } | 
                Should -Throw "Either StartDate or DaysToLookBack must be specified in non-interactive mode"
        }

        It 'Should process valid StartDate and EndDate combination' {
            # Arrange
            $currentDate = Get-Date
            $startDate = $currentDate.AddDays(-30)
            $endDate = $currentDate
            $PSBoundParameters = @{
                StartDate = $startDate
                EndDate = $endDate
            }

            # Act
            $result = Test-HawkDateParameter -PSBoundParameters $PSBoundParameters -StartDate $startDate -EndDate $endDate

            # Assert
            $result.StartDate | Should -Be $startDate.ToUniversalTime().Date
            $result.EndDate | Should -Be $endDate.ToUniversalTime().Date.AddDays(1)
        }
    }

    Context 'DaysToLookBack processing' {
        It 'Should correctly process DaysToLookBack with specified EndDate' {
            # Arrange
            $currentDate = Get-Date
            $endDate = $currentDate
            $daysToLook = 30
            $PSBoundParameters = @{
                DaysToLookBack = $daysToLook
                EndDate = $endDate
            }

            # Act
            $result = Test-HawkDateParameter -PSBoundParameters $PSBoundParameters -DaysToLookBack $daysToLook -EndDate $endDate

            # Assert
            $result.StartDate | Should -Be $endDate.ToUniversalTime().Date.AddDays(-$daysToLook)
            $result.EndDate | Should -Be $endDate.ToUniversalTime().Date.AddDays(1)
        }

        It 'Should calculate correct dates when only DaysToLookBack is provided' {
            # Arrange
            $currentDate = Get-Date
            $daysToLook = 30
            $PSBoundParameters = @{
                DaysToLookBack = $daysToLook
            }

            # Act
            $result = Test-HawkDateParameter -PSBoundParameters $PSBoundParameters -DaysToLookBack $daysToLook

            # Assert
            $result.EndDate | Should -Be $currentDate.ToUniversalTime().Date.AddDays(1)
            $result.StartDate | Should -Be $currentDate.ToUniversalTime().Date.AddDays(-$daysToLook)
        }
    }

    Context 'UTC conversion' {
        It 'Should convert dates to UTC and handle end date adjustment' {
            # Arrange
            $currentDate = Get-Date
            $startDate = $currentDate.AddDays(-30)
            $endDate = $currentDate
            $PSBoundParameters = @{
                StartDate = $startDate
                EndDate = $endDate
            }

            # Act
            $result = Test-HawkDateParameter -PSBoundParameters $PSBoundParameters -StartDate $startDate -EndDate $endDate

            # Assert
            $result.StartDate | Should -Be $startDate.ToUniversalTime().Date
            $result.EndDate | Should -Be $endDate.ToUniversalTime().Date.AddDays(1)
        }
    }


}