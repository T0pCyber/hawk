<#
.SYNOPSIS
    Compress all hawk data for upload
    Compresses all files located in the $Hawk.FilePath folder
.DESCRIPTION
    Compress all hawk data for upload
    Compresses all files located in the $Hawk.FilePath folder
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
Function Compress-HawkData {
    Out-LogFile ("Compressing all data in " + $Hawk.FilePath + " for Upload")
    # Make sure we don't already have a zip file
    if ($null -eq (Get-ChildItem *.zip -Path $Hawk.filepath)) { }
    else {
        Out-LogFile ("Removing existing zip file(s) from " + $Hawk.filepath)
        $allfiles = Get-ChildItem *.zip -Path $Hawk.FilePath
        # Remove the existing zip files
        foreach ($file in $allfiles) {
            $Error.Clear()
            Remove-Item $File.FullName -Confirm:$false -ErrorAction SilentlyContinue
            # Make sure we didn't throw an error when we tried to remove them
            if ($Error.Count -gt 0) {
                Out-LogFile "Unable to remove existing zip files from " + $Hawk.filepath + " please remove them manually"
                Write-Error -Message "Unable to remove existing zip files from " + $Hawk.filepath + " please remove them manually" -ErrorAction Stop
            }
            else { }
        }
    }



    # Get all of the files in the output directory
    #[array]$allfiles = Get-ChildItem -Path $Hawk.filepath -Recurse
    #Out-LogFile ("Found " + $allfiles.count + " files to add to zip")

    # create the zip file name
    [string]$zipname = "Hawk_" + (Split-path $Hawk.filepath -Leaf) + ".zip"
    [string]$zipfullpath = Join-Path $env:TEMP $zipname

    Out-LogFile ("Creating temporary zip file " + $zipfullpath)

    # Load the zip assembly
    Add-Type -Assembly System.IO.Compression.FileSystem

    # Create the zip file from the current hawk file directory
    [System.IO.Compression.ZipFile]::CreateFromDirectory($Hawk.filepath, $zipfullpath)

    # Move the item from the temp directory to the full filepath
    Out-LogFile ("Moving file to the " + $hawk.filepath + " directory")
    Move-Item $zipfullpath (Join-Path $Hawk.filepath $zipname)

}