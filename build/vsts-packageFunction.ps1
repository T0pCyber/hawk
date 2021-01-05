
<#
	.SYNOPSIS
		Packages an Azure Functions project, ready to release.
	
	.DESCRIPTION
		Packages an Azure Functions project, ready to release.
		Should be part of the release pipeline, after ensuring validation.

		Look into the 'AzureFunctionRest' template for generating functions for the module if you do.
	
	.PARAMETER WorkingDirectory
		The root folder to work from.
	
	.PARAMETER Repository
		The name of the repository to use for gathering dependencies from.
#>
param (
	$WorkingDirectory = "$($env:SYSTEM_DEFAULTWORKINGDIRECTORY)\_Hawk",
	
	$Repository = 'PSGallery',

	[switch]
	$IncludeAZ
)

$moduleName = 'Hawk'

# Prepare Paths
Write-PSFMessage -Level Host -Message "Creating working folders"
$moduleRoot = Join-Path -Path $WorkingDirectory -ChildPath 'publish'
$workingRoot = New-Item -Path $WorkingDirectory -Name 'working' -ItemType Directory
$modulesFolder = New-Item -Path $workingRoot.FullName -Name Modules -ItemType Directory

# Fill out the modules folder
Write-PSFMessage -Level Host -Message "Transfering built module data into working directory"
Copy-Item -Path "$moduleRoot\$moduleName" -Destination $modulesFolder.FullName -Recurse -Force
foreach ($dependency in (Import-PowerShellDataFile -Path "$moduleRoot\$moduleName\$moduleName.psd1").RequiredModules)
{
	$param = @{
		Repository = $Repository
		Name	   = $dependency.ModuleName
		Path	   = $modulesFolder.FullName
	}
	if ($dependency -is [string]) { $param['Name'] = $dependency }
	if ($dependency.RequiredVersion)
	{
		$param['RequiredVersion'] = $dependency.RequiredVersion
	}
	Write-PSFMessage -Level Host -Message "Preparing Dependency: $($param['Name'])"
	Save-Module @param
}

# Generate function configuration
Write-PSFMessage -Level Host -Message 'Generating function configuration'
$runTemplate = Get-Content -Path "$($WorkingDirectory)\azFunctionResources\run.ps1" -Raw
foreach ($functionSourceFile in (Get-ChildItem -Path "$($moduleRoot)\$moduleName\functions" -Recurse -Filter '*.ps1'))
{
	Write-PSFMessage -Level Host -Message "  Processing function: $functionSourceFile"
	$condensedName = $functionSourceFile.BaseName -replace '-', ''
	$functionFolder = New-Item -Path $workingRoot.FullName -Name $condensedName -ItemType Directory
	
	#region Load Overrides
	$override = @{ }
	if (Test-Path -Path "$($WorkingDirectory)\azFunctionResources\functionOverride\$($functionSourceFile.BaseName).psd1")
	{
		$override = Import-PowerShellDataFile -Path "$($WorkingDirectory)\azFunctionResources\functionOverride\$($functionSourceFile.BaseName).psd1"
	}
	if (Test-Path -Path "$($WorkingDirectory)\azFunctionResources\functionOverride\$($condensedName).psd1")
	{
		$override = Import-PowerShellDataFile -Path "$($WorkingDirectory)\azFunctionResources\functionOverride\$($condensedName).psd1"
	}
	#endregion Load Overrides
	
	#region Create Function Configuration
	$restMethods = 'get', 'post'
	if ($override.RestMethods) { $restMethods = $override.RestMethods }
	
	Set-Content -Path "$($functionFolder.FullName)\function.json" -Value @"
{
    "bindings": [
        {
        "authLevel": "function",
        "type": "httpTrigger",
        "direction": "in",
        "name": "Request",
        "methods": [
            "$($restMethods -join "`",
            `"")"
        ]
        },
        {
        "type": "http",
        "direction": "out",
        "name": "Response"
        }
    ],
    "disabled": false
}
"@
	#endregion Create Function Configuration
	
	#region Override Function Configuration
	if (Test-Path -Path "$($WorkingDirectory)\azFunctionResources\functionOverride\$($functionSourceFile.BaseName).json")
	{
		Copy-Item -Path "$($WorkingDirectory)\azFunctionResources\functionOverride\$($functionSourceFile.BaseName).json" -Destination "$($functionFolder.FullName)\function.json" -Force
	}
	if (Test-Path -Path "$($WorkingDirectory)\azFunctionResources\functionOverride\$($condensedName).json")
	{
		Copy-Item -Path "$($WorkingDirectory)\azFunctionResources\functionOverride\$($condensedName).json" -Destination "$($functionFolder.FullName)\function.json" -Force
	}
	#endregion Override Function Configuration
	
	# Generate the run.ps1 file
	$runText = $runTemplate -replace '%functionname%', $functionSourceFile.BaseName
	$runText | Set-Content -Path "$($functionFolder.FullName)\run.ps1" -Encoding UTF8
}

# Transfer common files
Write-PSFMessage -Level Host -Message "Transfering core function data"
if ($IncludeAZ)
{
	Copy-Item -Path "$($WorkingDirectory)\azFunctionResources\host-az.json" -Destination "$($workingroot.FullName)\host.json"
	Copy-Item -Path "$($WorkingDirectory)\azFunctionResources\requirements.psd1" -Destination "$($workingroot.FullName)\"
}
else
{
	Copy-Item -Path "$($WorkingDirectory)\azFunctionResources\host.json" -Destination "$($workingroot.FullName)\"
}
Copy-Item -Path "$($WorkingDirectory)\azFunctionResources\local.settings.json" -Destination "$($workingroot.FullName)\"

# Build the profile file
$text = @()
$text += Get-Content -Path "$($WorkingDirectory)\azFunctionResources\profile.ps1" -Raw
foreach ($functionFile in (Get-ChildItem "$($WorkingDirectory)\azFunctionResources\profileFunctions" -Recurse))
{
	$text += Get-Content -Path $functionFile.FullName -Raw
}
$text -join "`n`n" | Set-Content "$($workingroot.FullName)\profile.ps1"

# Zip It
Write-PSFMessage -Level Host -Message "Creating function archive in '$($WorkingDirectory)\$moduleName.zip'"
Compress-Archive -Path "$($workingroot.FullName)\*" -DestinationPath "$($WorkingDirectory)\$moduleName.zip" -Force