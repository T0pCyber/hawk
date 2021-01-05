<#
.SYNOPSIS
    Adds the data to an XML report
.DESCRIPTION
    Adds the data to an XML report
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
Function Out-Report {
    Param
    (
        [Parameter(Mandatory = $true)]
        [string]$Identity,
        [Parameter(Mandatory = $true)]
        [string]$Property,
        [Parameter(Mandatory = $true)]
        [string]$Value,
        [string]$Description,
        [string]$State,
        [string]$Link
    )

    # Force the case on all our critical values
    #$Property = $Property.tolower()
    #$Identity = $Identity.tolower()

    # Set our output path
    # Single report file for all outputs user/tenant/etc.
    # This might change in the future???
    $reportpath = Join-path $hawk.filepath report.xml

    # Switch statement to handle the state to color mapping
    switch ($State) {
        Warning { $highlighcolor = "#FF8000" }
        Success { $highlighcolor = "Green" }
        Error { $highlighcolor = "#8A0808" }
        default { $highlighcolor = "Light Grey" }
    }

    # Check if we have our XSL file in the output directory
    $xslpath = Join-path $hawk.filepath Report.xsl

    if (Test-Path $xslpath ) { }
    else {
        # Copy the XSL file into the current output path
        $sourcepath = join-path (split-path (Get-Module Hawk).path) report.xsl
        if (test-path $sourcepath) {
            Copy-Item -Path $sourcepath -Destination $hawk.filepath
        }
        # If we couldn't find it throw and error and stop
        else {
            Write-Error ("Unable to find transform file " + $sourcepath) -ErrorAction Stop
        }
    }

    # See if we have already created a report file
    # If so we need to import it
    if (Test-path $reportpath) {
        $reportxml = $null
        [xml]$reportxml = get-content $reportpath
    }
    # Since we have NOTHING we will create a new XML and just add / save / and exit
    else {
        Out-LogFile ("Creating new Report file" + $reportpath)
        # Create the report xml object
        $reportxml = New-Object xml

        # Create the xml declaraiton and stylesheet
        $reportxml.AppendChild($reportxml.CreateXmlDeclaration("1.0", $null, $null)) | Out-Null
        # $xmlstyle = "type=`"text/xsl`" href=`"https://csshawk.azurewebsites.net/report.xsl`""
        # $reportxml.AppendChild($reportxml.CreateProcessingInstruction("xml-stylesheet",$xmlstyle)) | Out-Null

        # Create all of the needed elements
        $newreport = $reportxml.CreateElement("report")
        $newentity = $reportxml.CreateElement("entity")
        $newentityidentity = $reportxml.CreateElement("identity")
        $newentityproperty = $reportxml.CreateElement("property")
        $newentitypropertyname = $reportxml.CreateElement("name")
        $newentitypropertyvalue = $reportxml.CreateElement("value")
        $newentitypropertycolor = $reportxml.CreateElement("color")
        $newentitypropertydescription = $reportxml.CreateElement("description")
        $newentitypropertylink = $reportxml.CreateElement("link")

        ### Build the XML from the bottom up ###
        # Add the property values to the entity object
        $newentityproperty.AppendChild($newentitypropertyname) | Out-Null
        $newentityproperty.AppendChild($newentitypropertyvalue) | Out-Null
        $newentityproperty.AppendChild($newentitypropertycolor) | Out-Null
        $newentityproperty.AppendChild($newentitypropertydescription) | Out-Null
        $newentityproperty.AppendChild($newentitypropertylink) | Out-Null

        # Set the values for the leaf nodes we just added
        $newentityproperty.name = $Property
        $newentityproperty.value = $Value
        $newentityproperty.color = $highlighcolor
        $newentityproperty.description = $Description
        $newentityproperty.link = $Link

        # Add the identity element to the entity and set its value
        $newentity.AppendChild($newentityidentity) | Out-Null
        $newentity.identity = $Identity

        # Add the property to the entity
        $newentity.AppendChild($newentityproperty) | Out-Null

        # Add the entity to the report
        $newreport.AppendChild($newentity) | Out-Null

        # Add the whole thing to the xml root
        $reportxml.AppendChild($newreport) | Out-Null

        # save the xml
        $reportxml.save($reportpath)
    }

    # We need to check if an entity with the ID $identity already exists
    if ($reportxml.report.entity.identity.contains($Identity)) { }
    # Didn't find and entity so we are going to create the whole thing and once
    else {
        # Create all of the needed elements
        $newentity = $reportxml.CreateElement("entity")
        $newentityidentity = $reportxml.CreateElement("identity")
        $newentityproperty = $reportxml.CreateElement("property")
        $newentitypropertyname = $reportxml.CreateElement("name")
        $newentitypropertyvalue = $reportxml.CreateElement("value")
        $newentitypropertycolor = $reportxml.CreateElement("color")
        $newentitypropertydescription = $reportxml.CreateElement("description")
        $newentitypropertylink = $reportxml.CreateElement("link")

        ### Build the XML from the bottom up ###
        # Add the property values to the entity object
        $newentityproperty.AppendChild($newentitypropertyname) | Out-Null
        $newentityproperty.AppendChild($newentitypropertyvalue) | Out-Null
        $newentityproperty.AppendChild($newentitypropertycolor) | Out-Null
        $newentityproperty.AppendChild($newentitypropertydescription) | Out-Null
        $newentityproperty.AppendChild($newentitypropertylink) | Out-Null

        # Set the values for the leaf nodes we just added
        $newentityproperty.name = $Property
        $newentityproperty.value = $Value
        $newentityproperty.color = $highlighcolor
        $newentityproperty.description = $Description
        $newentityproperty.link = $Link

        # Add them together and set values
        $newentity.AppendChild($newentityidentity) | Out-Null
        $newentity.identity = $Identity
        $newentity.AppendChild($newentityproperty) | Out-Null

        # Add the new entity stub back to the XML
        $reportxml.report.AppendChild($newentity) | Out-Null
    }

    # Now we need to check for the property we are looking to add
    # The property exists so we need to update it
    if (($reportxml.report.entity | Where-Object { $_.identity -eq $Identity }).property.name.contains($Property)) {
        ### Update existing property ###
        (($reportxml.report.entity | Where-Object { $_.identity -eq $Identity }).property | Where-Object { $_.name -eq $Property }).value = $Value
        (($reportxml.report.entity | Where-Object { $_.identity -eq $Identity }).property | Where-Object { $_.name -eq $Property }).color = $highlighcolor
        (($reportxml.report.entity | Where-Object { $_.identity -eq $Identity }).property | Where-Object { $_.name -eq $Property }).description = $Description
        (($reportxml.report.entity | Where-Object { $_.identity -eq $Identity }).property | Where-Object { $_.name -eq $Property }).link = $Link
    }
    # We need to add the property to the entity
    else {
        ### Add new property to existing Entity ###
        # Create the elements that we are going to need
        $newproperty = $reportxml.CreateElement("property")
        $newname = $reportxml.CreateElement("name")
        $newvalue = $reportxml.CreateElement("value")
        $newcolor = $reportxml.CreateElement("color")
        $newdescription = $reportxml.CreateElement("description")
        $newlink = $reportxml.CreateElement("link")

        # Add on all of the elements
        $newproperty.AppendChild($newname) | Out-Null
        $newproperty.AppendChild($newvalue) | Out-Null
        $newproperty.AppendChild($newcolor) | Out-Null
        $newproperty.AppendChild($newdescription) | Out-Null
        $newproperty.AppendChild($newlink) | Out-Null

        # Set the values
        $newproperty.name = $Property
        $newproperty.value = $Value
        $newproperty.color = $highlighcolor
        $newproperty.description = $Description
        $newproperty.link = $Link

        # Add the newly created property to the entity
        ($reportxml.report.entity | Where-Object { $_.identity -eq $Identity }).AppendChild($newproperty) | Out-Null
    }

    # Make sure we save our changes
    $reportxml.Save($reportpath)

    # Convert it to HTML and Save
    Convert-ReportToHTML -Xml $reportpath -Xsl $xslpath
}