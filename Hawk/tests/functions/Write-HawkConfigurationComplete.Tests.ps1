# Tests for Write-HawkConfigurationComplete function which displays Hawk's configuration settings
Describe "Write-HawkConfigurationComplete" {
    BeforeAll {
        # Mock the logging function to prevent actual logging during tests
        # This allows us to verify what would have been logged without writing files
        Mock Out-LogFile {}
        
        # Create a test configuration object that mimics the real Hawk global object
        # This provides known values we can verify against in our tests
        $testHawk = [PSCustomObject]@{
            FilePath = "C:\Test"                    # Test file output path
            StartDate = Get-Date "2024-01-01"       # Investigation start date
            EndDate = Get-Date "2024-01-31"         # Investigation end date
            DaysToLookBack = 30                     # Number of days to search
            WhenCreated = Get-Date "2024-01-23"     # When config was created
        }

        # Mock Get-Module to return a consistent version number
        # This ensures our tests aren't affected by actual module versions
        Mock Get-Module { 
            return [PSCustomObject]@{ Version = "3.2.4" }
        } -ParameterFilter { $Name -eq 'Hawk' }
    }

    # Test that the function writes the expected header messages
    # This verifies the basic welcome and setup messages are displayed
    It "Should write configuration settings to log" {
        Write-HawkConfigurationComplete -Hawk $testHawk

        # Verify the configuration complete message
        Should -Invoke Out-LogFile -ParameterFilter { 
            $string -eq "Configuration Complete!" -and
            $Information -eq $true
        }

        # Verify the environment setup message
        Should -Invoke Out-LogFile -ParameterFilter {
            $string -eq "Your Hawk environment is now set up with the following settings:" -and 
            $Information -eq $true
        }

        # Verify the version information is displayed
        Should -Invoke Out-LogFile -ParameterFilter {
            $string -eq "Hawk Version: 3.2.4" -and
            $Information -eq $true
        }
    }

    # Test that all properties of the Hawk object are properly logged
    # This ensures no configuration settings are missed in the output
    It "Should log all Hawk object properties" {
        Write-HawkConfigurationComplete -Hawk $testHawk

        # Check each property is logged with its value
        foreach ($prop in $testHawk.PSObject.Properties) {
            # Verify property name and value appear in log message
            Should -Invoke Out-LogFile -ParameterFilter {
                $string -like "*$($prop.Name)*$($prop.Value)*" -and
                $Information -eq $true
            }
        }
    }

    # Test the handling of null values in the configuration
    # This ensures the function properly handles missing or undefined settings
    It "Should display N/A for null values" {
        # Create a test object with null properties
        $nullHawk = [PSCustomObject]@{
            FilePath = $null
            StartDate = $null
        }

        Write-HawkConfigurationComplete -Hawk $nullHawk

        # Verify null values are displayed as "N/A"
        Should -Invoke Out-LogFile -ParameterFilter {
            $string -like "*FilePath = N/A*" -and
            $Information -eq $true
        }
    }

    # Test that the function accepts pipeline input
    # This verifies the function works with PowerShell pipelines
    It "Should accept pipeline input" {
        # Verify no errors when using pipeline input
        { $testHawk | Write-HawkConfigurationComplete } | Should -Not -Throw

        # Verify logging occurred at least once
        Should -Invoke Out-LogFile -Minimum 1
    }

    # Optional: Test error handling
    It "Should throw an error with null input" {
        # Verify the function properly handles null input
        { Write-HawkConfigurationComplete -Hawk $null } | Should -Throw
    }
}