
<#
	.SYNOPSIS
		Build script that generates a client module for REST API endpoints of a Azure PowerShell Functions project.
	
	.DESCRIPTION
		Build script that generates a client module for REST API endpoints of a Azure PowerShell Functions project.
	
	.PARAMETER ApiKey
		The API key to use to publish the module to a Nuget Repository
	
	.PARAMETER WorkingDirectory
		The root folder from which to build the module.
	
	.PARAMETER Repository
		The name of the repository to publish to.
		Defaults to PSGallery.
	
	.PARAMETER LocalRepo
		Instead of publishing to a gallery, drop a nuget package in the root folder.
		This package can then be picked up in a later step for publishing to Azure Artifacts.

	.PARAMETER ModuleName
		The name to give to the client module.
		By default, the client module will be named '<ModuleName>.Client'.
	
	.PARAMETER IncludeFormat
		Include the format xml of the source module for the client module.
	
	.PARAMETER IncludeType
		Include the type extension xml of the source module for the client module.
	
	.PARAMETER IncludeAssembly
		Include the binaries of the source module for the client module.
#>
param (
	$ApiKey,
	
	$WorkingDirectory,
	
	$Repository = 'PSGallery',
	
	[switch]
	$LocalRepo,
	
	$ModuleName,
	
	[switch]
	$IncludeFormat,
	
	[switch]
	$IncludeType,
	
	[switch]
	$IncludeAssembly
)

#region Handle Working Directory Defaults
if (-not $WorkingDirectory)
{
	if ($env:RELEASE_PRIMARYARTIFACTSOURCEALIAS)
	{
		$WorkingDirectory = Join-Path -Path $env:SYSTEM_DEFAULTWORKINGDIRECTORY -ChildPath $env:RELEASE_PRIMARYARTIFACTSOURCEALIAS
	}
	else { $WorkingDirectory = $env:SYSTEM_DEFAULTWORKINGDIRECTORY }
}
#endregion Handle Working Directory Defaults

Write-PSFMessage -Level Host -Message 'Starting Build: Client Module'
$parentModule = 'Hawk'
if (-not $ModuleName) { $ModuleName = 'Hawk.Client' }
Write-PSFMessage -Level Host -Message 'Creating Folder Structure'
$workingRoot = New-Item -Path $WorkingDirectory -Name $ModuleName -ItemType Directory
$publishRoot = Join-Path -Path $WorkingDirectory -ChildPath 'publish\Hawk'
Copy-Item -Path "$($WorkingDirectory)\azFunctionResources\clientModule\functions" -Destination "$($workingRoot.FullName)\" -Recurse
Copy-Item -Path "$($WorkingDirectory)\azFunctionResources\clientModule\internal" -Destination "$($workingRoot.FullName)\" -Recurse
Copy-Item -Path "$($publishRoot)\en-us" -Destination "$($workingRoot.FullName)\" -Recurse
$functionFolder = Get-Item -Path "$($workingRoot.FullName)\functions"

#region Create Functions
$encoding = [PSFEncoding]'utf8'
$functionsText = Get-Content -Path "$($WorkingDirectory)\azFunctionResources\clientModule\function.ps1" -Raw

Write-PSFMessage -Level Host -Message 'Creating Functions'
foreach ($functionSourceFile in (Get-ChildItem -Path "$($publishRoot)\functions" -Recurse -Filter '*.ps1'))
{
	Write-PSFMessage -Level Host -Message "  Processing function: $($functionSourceFile.BaseName)"
	$condensedName = $functionSourceFile.BaseName -replace '-', ''
	
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
	if ($override.NoClientFunction)
	{
		Write-PSFMessage -Level Host -Message "    Override 'NoClientFunction' detected, skipping!"
		continue
	}
	
	# If there is an definition override, use it and continue
	if (Test-Path -Path "$($WorkingDirectory)\azFunctionResources\functionOverride\$($functionSourceFile.BaseName).ps1")
	{
		Write-PSFMessage -Level Host -Message "    Override function definition detected, using override"
		Copy-Item -Path "$($WorkingDirectory)\azFunctionResources\functionOverride\$($functionSourceFile.BaseName).ps1" -Destination $functionFolder.FullName
		continue
	}
	
	# Figure out the Rest Method to use
	$methodName = 'Post'
	if ($override.RestMethods)
	{
		$methodName = $override.RestMethods | Where-Object { $_ -ne 'Get' } | Select-Object -First 1
	}
	
	#endregion Load Overrides
	
	$currentFunctionsText = $functionsText -replace '%functionname%', $functionSourceFile.BaseName -replace '%condensedname%', $condensedName -replace '%method%', $methodName
	
	$parsedFunction = Read-PSMDScript -Path $functionSourceFile.FullName
	$functionAst = $parsedFunction.Ast.EndBlock.Statements | Where-Object {
		$_ -is [System.Management.Automation.Language.FunctionDefinitionAst]
	} | Select-Object -First 1
	
	$end = $functionAst.Body.ParamBlock.Extent.EndOffSet
	$start = $functionAst.Body.Extent.StartOffSet + 1
	$currentFunctionsText = $currentFunctionsText.Replace('%parameter%', $functionAst.Body.Extent.Text.SubString(1, ($end - $start)))
	
	Write-PSFMessage -Level Host -Message "    Creating file: $($functionFolder.FullName)\$($functionSourceFile.Name)"
	[System.IO.File]::WriteAllText("$($functionFolder.FullName)\$($functionSourceFile.Name)", $currentFunctionsText, $encoding)
}
$functionsToExport = (Get-ChildItem -Path $functionFolder.FullName -Recurse -Filter *.ps1).BaseName | Sort-Object
#endregion Create Functions

#region Create Core Module Files
# Get Manifest of published version, in order to catch build-phase changes such as module version.
$originalManifestData = Import-PowerShellDataFile -Path "$publishRoot\Hawk.psd1"
$prereqHash = @{
	ModuleName    = 'PSFramework'
	ModuleVersion = (Get-Module PSFramework).Version
}
$paramNewModuleManifest = @{
	Path			  = ('{0}\{1}.psd1' -f $workingRoot.FullName, $ModuleName)
	FunctionsToExport = $functionsToExport
	CompanyName	      = $originalManifestData.CompanyName
	Author		      = $originalManifestData.Author
	Description	      = $originalManifestData.Description
	ModuleVersion	  = $originalManifestData.ModuleVersion
	RootModule	      = ('{0}.psm1' -f $ModuleName)
	Copyright		  = $originalManifestData.Copyright
	TypesToProcess    = @()
	FormatsToProcess  = @()
	RequiredAssemblies = @()
	RequiredModules   = @($prereqHash)
	CompatiblePSEditions = 'Core', 'Desktop'
	PowerShellVersion = '5.1'
}

if ($IncludeAssembly) { $paramNewModuleManifest.RequiredAssemblies = $originalManifestData.RequiredAssemblies }
if ($IncludeFormat) { $paramNewModuleManifest.FormatsToProcess = $originalManifestData.FormatsToProcess }
if ($IncludeType) { $paramNewModuleManifest.TypesToProcess = $originalManifestData.TypesToProcess }
Write-PSFMessage -Level Host -Message "Creating Module Manifest for module: $ModuleName"
New-ModuleManifest @paramNewModuleManifest

Write-PSFMessage -Level Host -Message "Copying additional module files"
Copy-Item -Path "$($WorkingDirectory)\azFunctionResources\clientModule\moduleroot.psm1" -Destination "$($workingRoot.FullName)\$($ModuleName).psm1"
Copy-Item -Path "$($WorkingDirectory)\LICENSE" -Destination "$($workingRoot.FullName)\"
#endregion Create Core Module Files

#region Transfer Additional Content
if ($IncludeAssembly)
{
	Copy-Item -Path "$publishRoot\bin" -Destination "$($workingRoot.FullName)\" -Recurse
}
if ($IncludeFormat -or $IncludeType)
{
	Copy-Item -Path "$publishRoot\xml" -Destination "$($workingRoot.FullName)\" -Recurse
}
#endregion Transfer Additional Content

#region Publish
if ($LocalRepo)
{
	# Dependencies must go first
	Write-PSFMessage -Level Important -Message "Creating Nuget Package for module: PSFramework"
	New-PSMDModuleNugetPackage -ModulePath (Get-Module -Name PSFramework).ModuleBase -PackagePath . -WarningAction SilentlyContinue
	Write-PSFMessage -Level Important -Message "Creating Nuget Package for module: Hawk"
	New-PSMDModuleNugetPackage -ModulePath $workingRoot.FullName -PackagePath . -EnableException
}
else
{
	# Publish to Gallery
	Write-PSFMessage -Level Important -Message "Publishing the Hawk module to $($Repository)"
	Publish-Module -Path $workingRoot.FullName -NuGetApiKey $ApiKey -Force -Repository $Repository
}
#endregion Publish