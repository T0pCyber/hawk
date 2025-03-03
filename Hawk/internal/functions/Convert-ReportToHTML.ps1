<#
.SYNOPSIS
    Convert a reportxml to html
.DESCRIPTION
    Convert a reportxml to html
.PARAMETER xml
    XML format
.PARAMETER xsl
    XLS format
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
Function Convert-ReportToHTML
{
    param
    (
        [Parameter(Mandatory = $true)]
        $Xml,
        [Parameter(Mandatory = $true)]
        $Xsl
    )

    begin
    {
        # Make sure that the files are there
        if (!(Test-Path $Xml))
        {
            Write-Error "XML File not found for conversion" -ErrorAction Stop
        }
        if (!(Test-Path $Xsl))
        {
            Write-Error "XSL File not found for Conversion" -ErrorAction Stop
        }
    }

    process
    {
        # Create the output file name
        $OutputFile = Join-Path (Split-Path $xml) ((Split-Path $xml -Leaf).split(".")[0] + ".html")

        # Run the transform on the XML and produce the HTML
        $xslt = New-Object System.Xml.Xsl.XslCompiledTransform
        $xslt.Load($xsl)
        $xslt.Transform($xml, $OutputFile)
    }
    end
    { }
}