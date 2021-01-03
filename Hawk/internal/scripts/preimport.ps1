<#
Add all things you want to run before importing the main function code.

WARNING: ONLY provide paths to files!

After building the module, this file will be completely ignored, adding anything but paths to files ...
- Will not work after publishing
- Could break the build process
#>

$moduleRoot = Split-Path (Split-Path $PSScriptRoot)

# Load the strings used in messages
"$moduleRoot\internal\scripts\strings.ps1"