<#
.SYNOPSIS
    Convert a reportxml to html
.DESCRIPTION
    Convert a reportxml to html
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
Function Convert-ReportToHTML {
    param
    (
        [Parameter(Mandatory = $true)]
        $Xml,
        [Parameter(Mandatory = $true)]
        $Xsl
    )

    begin {
        # Make sure that the files are there
        if (!(test-path $Xml)) {
            Write-Error "XML File not found for conversion" -ErrorAction Stop
        }
        if (!(test-path $Xsl)) {
            Write-Error "XSL File not found for Conversion" -ErrorAction Stop
        }
    }

    process {
        # Create the output file name
        $OutputFile = Join-Path (Split-path $xml) ((split-path $xml -Leaf).split(".")[0] + ".html")

        # Run the transform on the XML and produce the HTML
        $xslt = New-Object System.Xml.Xsl.XslCompiledTransform;
        $xslt.Load($xsl);
        $xslt.Transform($xml, $OutputFile);
    }
    end
    { }
}