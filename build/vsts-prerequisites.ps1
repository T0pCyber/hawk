#vsts-prequisites.ps1

param (
    [string]
    $Repository = 'PSGallery'
)

$modules = @("Pester", "PSFramework", "PSModuleDevelopment")

# Automatically add missing dependencies
# Do we need to keep this?

# $data = Import-PowerShellDataFile -Path "$PSScriptRoot\..\Hawk\Hawk.psd1"
# foreach ($dependency in $data.RequiredModules) {
#     if ($dependency -is [string]) {
#         if ($modules -contains $dependency) { continue }
#         $modules += $dependency
#     }
#     else {
#         if ($modules -contains $dependency.ModuleName) { continue }
#         $modules += $dependency.ModuleName
#     }
# }

foreach ($module in $modules) {
    Write-Output "Installing module: $module"
    Install-Module $module -Force -SkipPublisherCheck -Repository $Repository
    Import-Module $module -Force -PassThru
}