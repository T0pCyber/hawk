Function Convert-OutputFormatToParameters {
    <#
    .SYNOPSIS
        Converts an array of output format strings into a hashtable of switch parameters.

    .DESCRIPTION
        This function accepts an array of strings representing output formats (such as JSON, NDJSON, CSV, and TXT)
        and converts them into a hashtable where each key corresponds to a lowercase version of the format with a value
        of $true. The resulting hashtable can then be splatted into functions (like Out-MultipleFileType) that require
        individual switch parameters for each output format.

    .PARAMETER OutputFormat
        An array of strings specifying the output format(s). Valid options are JSON, NDJSON, CSV, and TXT.

    .OUTPUTS
        [System.Collections.Hashtable]
        Hashtable containing keys (json, ndjson, csv, txt) with a value of $true for each format specified.

    .EXAMPLE
        PS C:\> $params = Convert-OutputFormatToParameters -OutputFormat @("JSON", "CSV")
        This returns a hashtable:
        @{ json = $true; csv = $true }

    .EXAMPLE
        PS C:\> $params = Convert-OutputFormatToParameters -OutputFormat "NDJSON"
        This returns a hashtable:
        @{ ndjson = $true }

    .NOTES
        The keys in the returned hashtable are all lowercase.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet('JSON','NDJSON','CSV','TXT')]
        [string[]]$OutputFormat
    )

    $outParams = @{}
    foreach ($format in $OutputFormat) {
        switch ($format.ToUpper()) {
            'JSON'    { $outParams['json'] = $true }
            'NDJSON'  { $outParams['ndjson'] = $true }
            'CSV'     { $outParams['csv'] = $true }
            'TXT'     { $outParams['txt'] = $true }
        }
    }
    return $outParams
}
