<#
This is an example configuration file

By default, it is enough to have a single one of them,
however if you have enough configuration settings to justify having multiple copies of it,
feel totally free to split them into multiple files.
#>

<#
# Example Configuration
Set-PSFConfig -Module 'Hawk' -Name 'Example.Setting' -Value 10 -Initialize -Validation 'integer' -Handler { } -Description "Example configuration setting. Your module can then use the setting using 'Get-PSFConfigValue'"
#>

Set-PSFConfig -Module 'Hawk' -Name 'Import.DoDotSource' -Value $false -Initialize -Validation 'bool' -Description "Whether the module files should be dotsourced on import. By default, the files of this module are read as string value and invoked, which is faster but worse on debugging."
Set-PSFConfig -Module 'Hawk' -Name 'Import.IndividualFiles' -Value $false -Initialize -Validation 'bool' -Description "Whether the module files should be imported individually. During the module build, all module code is compiled into few files, which are imported instead by default. Loading the compiled versions is faster, using the individual files is easier for debugging and testing out adjustments."

Set-PSFConfig -Module 'Hawk' -Name 'DaysToLookBack' -Value 90 -Initialize -Validation integerpositive -Description 'How long into the past will the project look'

$handler = {
	$paramSetPSFLoggingProvider = @{
		Name		   = 'logfile'
		InstanceName   = 'Hawk'
		FilePath	   = Join-Path -path $args[0] -ChildPath '%date%_logs.csv'
		TimeFormat	   = 'yyyy-MM-dd HH:mm:ss.fff'
		IncludeModules = 'Hawk'
		UTC		       = $true
		Enabled	       = $true
	}

	Set-PSFLoggingProvider @paramSetPSFLoggingProvider
}
Set-PSFConfig -Module 'Hawk' -Name "FilePath" -Value '' -Initialize -Validation string -Handler $handler -Description 'Path where the module maintains logs and export data'