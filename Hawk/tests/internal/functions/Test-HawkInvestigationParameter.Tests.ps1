Describe 'Test-HawkInvestigationParameter' {
    BeforeAll {
        # Mock Test-Path to handle both -IsValid and normal path checks
        Mock Test-Path -ModuleName Hawk {
            param($Path)
            if ($Path -eq 'C:\ValidPath') {
                return $true
            }
            return $false
        }
    }

    Context 'When validating FilePath parameter' {
        It 'Should fail when FilePath is missing in non-interactive mode' {
            # Arrange
            $startDate = Get-Date
            $endDate = $startDate.AddDays(30)
            
            # Act
            $result = Test-HawkInvestigationParameter `
                -StartDate $startDate `
                -EndDate $endDate `
                -NonInteractive
            
            # Assert
            $result.IsValid | Should -BeFalse
            $result.ErrorMessages | Should -Contain 'FilePath parameter is required in non-interactive mode'
        }

        It 'Should fail when FilePath is invalid' {
            # Arrange
            $startDate = Get-Date
            $endDate = $startDate.AddDays(30)
            $invalidPath = "Z:\NonExistentPath\Invalid"
            
            # Act
            $result = Test-HawkInvestigationParameter `
                -StartDate $startDate `
                -EndDate $endDate `
                -FilePath $invalidPath `
                -NonInteractive
            
            # Assert
            $result.IsValid | Should -BeFalse
            $result.ErrorMessages | Should -Contain "Invalid file path provided: $invalidPath"
        }

        It 'Should pass when all required parameters are valid in non-interactive mode' {
            # Arrange
            $currentDate = Get-Date
            $startDate = $currentDate.AddDays(-30)
            $endDate = $currentDate
            $validPath = "C:\ValidPath"
            
            # Act
            $result = Test-HawkInvestigationParameter `
                -StartDate $startDate `
                -EndDate $endDate `
                -FilePath $validPath `
                -NonInteractive
            
            # Assert
            $result.IsValid | Should -BeTrue
            $result.ErrorMessages | Should -BeNullOrEmpty
        }
    }

    Context 'When validating in interactive mode' {
        It 'Should pass when valid dates are provided in interactive mode' {
            # Arrange
            $currentDate = Get-Date
            $startDate = $currentDate.AddDays(-30)
            $endDate = $currentDate
            $validPath = "C:\ValidPath"
            
            # Act
            $result = Test-HawkInvestigationParameter `
                -StartDate $startDate `
                -EndDate $endDate `
                -FilePath $validPath
            
            # Assert
            $result.IsValid | Should -BeTrue
            $result.ErrorMessages | Should -BeNullOrEmpty
        }

        It 'Should pass with DaysToLookBack in interactive mode' {
            # Arrange
            $validPath = "C:\ValidPath"
            
            # Act
            $result = Test-HawkInvestigationParameter `
                -DaysToLookBack 30 `
                -FilePath $validPath
            
            # Assert
            $result.IsValid | Should -BeTrue
            $result.ErrorMessages | Should -BeNullOrEmpty
        }
    }

    Context 'When validating date parameters' {
        It 'Should fail when StartDate is after EndDate' {
            # Arrange
            $startDate = Get-Date
            $endDate = $startDate.AddDays(-30)
            $validPath = "C:\ValidPath"
            
            # Act
            $result = Test-HawkInvestigationParameter `
                -StartDate $startDate `
                -EndDate $endDate `
                -FilePath $validPath `
                -NonInteractive
            
            # Assert
            $result.IsValid | Should -BeFalse
            $result.ErrorMessages | Should -Contain "StartDate must be before EndDate"
        }

        It 'Should fail when date range exceeds 365 days' {
            # Arrange
            $startDate = Get-Date
            $endDate = $startDate.AddDays(366)
            $validPath = "C:\ValidPath"
            
            # Act
            $result = Test-HawkInvestigationParameter `
                -StartDate $startDate `
                -EndDate $endDate `
                -FilePath $validPath `
                -NonInteractive
            
            # Assert
            $result.IsValid | Should -BeFalse
            $result.ErrorMessages | Should -Contain "Date range cannot exceed 365 days"
        }

        It 'Should fail when EndDate is more than one day in the future' {
            # Arrange
            $startDate = Get-Date
            $endDate = $startDate.AddDays(2)
            $validPath = "C:\ValidPath"
            
            # Act
            $result = Test-HawkInvestigationParameter `
                -StartDate $startDate `
                -EndDate $endDate `
                -FilePath $validPath `
                -NonInteractive
            
            # Assert
            $result.IsValid | Should -BeFalse
            $result.ErrorMessages | Should -Contain "EndDate cannot be more than one day in the future"
        }

        It 'Should fail when DaysToLookBack is 0' {
            # Arrange
            $validPath = "C:\ValidPath"
            
            # Act
            $result = Test-HawkInvestigationParameter `
                -DaysToLookBack 0 `
                -FilePath $validPath `
                -NonInteractive
            
            # Assert
            $result.IsValid | Should -BeFalse
            $result.ErrorMessages | Should -Contain "Either StartDate or DaysToLookBack must be specified in non-interactive mode"
        }

        It 'Should fail when DaysToLookBack is 366' {
            # Arrange
            $validPath = "C:\ValidPath"
            
            # Act
            $result = Test-HawkInvestigationParameter `
                -DaysToLookBack 366 `
                -FilePath $validPath `
                -NonInteractive
            
            # Assert
            $result.IsValid | Should -BeFalse
            $result.ErrorMessages | Should -Contain "DaysToLookBack must be between 1 and 365"
        }
    }

    Context 'When validating parameter combinations' {
        It 'Should pass when DaysToLookBack is used with EndDate but no StartDate' {
            # Arrange
            $validPath = "C:\ValidPath"
            $endDate = Get-Date
            
            # Act
            $result = Test-HawkInvestigationParameter `
                -DaysToLookBack 30 `
                -EndDate $endDate `
                -FilePath $validPath `
                -NonInteractive
            
            # Assert
            $result.IsValid | Should -BeTrue
            $result.ErrorMessages | Should -BeNullOrEmpty
        }

        It 'Should fail when DaysToLookBack is used with StartDate' {
            # Arrange
            $validPath = "C:\ValidPath"
            $startDate = Get-Date
            
            # Act
            $result = Test-HawkInvestigationParameter `
                -DaysToLookBack 30 `
                -StartDate $startDate `
                -FilePath $validPath `
                -NonInteractive
            
            # Assert
            $result.IsValid | Should -BeFalse
            $result.ErrorMessages | Should -Contain "EndDate must be specified when using StartDate in non-interactive mode"
        }
    }
}