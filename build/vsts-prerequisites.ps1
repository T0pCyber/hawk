param (
    [string]
    $Repository = 'PSGallery'
)

$modules = @(
    @{ Name = "Pester"; Version = "5.6.1" },
    "PSFramework",
    "PSModuleDevelopment"
)

# Load required modules from Hawk.psd1
$data = Import-PowerShellDataFile -Path "$PSScriptRoot\..\Hawk\Hawk.psd1"
foreach ($dependency in $data.RequiredModules) {
    # Handle string dependencies
    if ($dependency -is [string]) {
        if (-not ($modules -contains $dependency)) {
            $modules += @{ Name = $dependency; Version = "" }
        }
    }
    # Handle hashtable dependencies
    elseif ($dependency -is [hashtable]) {
        if (-not ($modules -contains $dependency.ModuleName)) {
            $modules += @{ Name = $dependency.ModuleName; Version = $dependency.RequiredVersion }
        }
    }
}

# Install and import modules
foreach ($module in $modules) {
    try {
        $moduleName = $module.Name
        $moduleVersion = $module.Version
        Write-Output "Installing $moduleName"
        Install-Module -Name $moduleName -RequiredVersion $moduleVersion -Force -SkipPublisherCheck -Repository $Repository
        Import-Module -Name $moduleName -Force -PassThru
    } catch {
        Write-Error "Failed to install or import module: $($module.Name). Error: $_"
    }
}
