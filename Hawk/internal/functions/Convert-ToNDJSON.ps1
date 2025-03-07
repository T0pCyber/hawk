Function Convert-ToNDJSON {
    <#
    .SYNOPSIS
        Converts PowerShell objects to Newline Delimited JSON (NDJSON) format.
    
    .DESCRIPTION
        This function converts PowerShell objects to Newline Delimited JSON (NDJSON) format,
        where each object is represented as a single line of JSON with no pretty-printing.
        This format is optimized for streaming and efficient processing by SIEM systems.
    
    .PARAMETER InputObject
        The PowerShell object(s) to convert to NDJSON format.
    
    .PARAMETER FilePath
        The path to the file where the NDJSON output should be written.
        If not specified, the function returns the NDJSON as a string.
    
    .PARAMETER Append
        If specified, appends the NDJSON to an existing file rather than overwriting it.
        Only applies when FilePath is specified.
    
    .PARAMETER Depth
        Specifies how many levels of contained objects are included in the JSON representation.
        The default value is 100. Maximum value is 100.
    
    .EXAMPLE
        $data | Convert-ToNDJSON -FilePath "output.ndjson"
        
        Converts the objects in $data to NDJSON format and saves them to "output.ndjson".
    
    .EXAMPLE
        $data | Convert-ToNDJSON -FilePath "output.ndjson" -Append
        
        Converts the objects in $data to NDJSON format and appends them to "output.ndjson".
    
    .EXAMPLE
        $ndjsonString = $data | Convert-ToNDJSON
        
        Converts the objects in $data to NDJSON format and returns the result as a string.
    
    .NOTES
        NDJSON is a format where each line is a valid JSON object, making it ideal for
        streaming data processing and for efficient ingestion into SIEM systems.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [PSObject]$InputObject,
        
        [Parameter()]
        [string]$FilePath,
        
        [Parameter()]
        [switch]$Append,
        
        [Parameter()]
        [ValidateRange(1, 100)]
        [int]$Depth = 100
    )
    
    begin {
        # Initialize a collection if we're returning a string
        if (-not $FilePath) {
            $ndjsonLines = [System.Collections.ArrayList]::new()
        }
        
        # If appending, ensure file exists
        if ($FilePath -and $Append -and -not (Test-Path -Path $FilePath)) {
            $Append = $false
        }
        
        # Create or clear the file if not appending
        if ($FilePath -and -not $Append) {
            Set-Content -Path $FilePath -Value $null -Force
        }
    }
    
    process {
        # Convert the object to compressed JSON
        $jsonLine = $InputObject | ConvertTo-Json -Compress -Depth $Depth
        
        if ($FilePath) {
            # Write directly to the file
            Add-Content -Path $FilePath -Value $jsonLine -Encoding UTF8
        }
        else {
            # Add to collection for later return
            $null = $ndjsonLines.Add($jsonLine)
        }
    }
    
    end {
        # Return the collected lines if we're not writing to a file
        if (-not $FilePath) {
            return ($ndjsonLines -join "`n")
        }
    }
}