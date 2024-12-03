#vsts-prequisites.ps1

param (
    [string]
    $Repository = 'PSGallery'
)

$modules = @(
    @{ Name = "Pester"; Version = "5.6.1" },
    "PSFramework",
    "PSModuleDevelopment"
)

# Automatically add missing dependencies
# TODO: uncomment this block of code below and fix RobustCloudCommand error.

$data = Import-PowerShellDataFile -Path "$PSScriptRoot\..\Hawk\Hawk.psd1"
foreach ($dependency in $data.RequiredModules) {
    if ($dependency -is [string]) {
        if ($modules -contains $dependency) { continue }
        $modules += $dependency
    }
    else {
        if ($modules -contains $dependency.ModuleName) { continue }
        $modules += $dependency.ModuleName
    }
}

foreach ($module in $modules) {
    # Write-Output "Installing module: $module"
    Write-Output "Installing $module"
    Install-Module $module -Force -SkipPublisherCheck -Repository $Repository
    Import-Module $module -Force -PassThru
}