<#
.SYNOPSIS
    Takes in a set of azure Authentication logs and combines them into a unified output
.DESCRIPTION
    Takes in a set of azure Authentication logs and combines them into a unified output
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
Function Import-AzureAuthenticationLogs {
    Param([array]$JsonConvertedLogs)

    # Null out the output object
    $Listoutput = $null
    $baseproperties = $null
    $i = 0

    # Create the output list array
    $ListOutput = New-Object System.Collections.ArrayList
    $baseproperties = New-Object System.Collections.ArrayList

    # Process each entry in the array
    foreach ($entry in $JsonConvertedLogs) {

        if ([bool]($i % 25)) { }
        Else {
            Write-Progress -Activity "Converting Json Entries" -CurrentOperation ("Entry " + $i) -PercentComplete (($i / $JsonConvertedLogs.count) * 100) -Status ("Processing")
        }

        # null out a temp object and create it as a new custom ps object
        $processedentry = $null
        $processedentry = New-Object -TypeName PSobject

        # Look at each member of the entry ... we want to process each in turn and add them to a new object
        foreach ($member in ($entry | get-member -MemberType NoteProperty)) {

            # Identity unique properties and add to property list of base object if not present
            if ($baseproperties -contains $member.name) { }
            else {
                $baseproperties.add($member.name) | Out-Null
            }

            # Switch statement to deal with known "special" properties
            switch ($member.name) {
                # Extended properties can contain addtional values so we need to expand those
                ExtendedProperties {
                    # Null check
                    if ($null -eq $entry.ExtendedProperties) { }
                    else {
                        # expand out each entry and add it to the base properties and to the property of our exported object
                        Foreach ($Object in $entry.ExtendedProperties) {
                            # Identity unique properties and add to property list of base object if not present
                            if ($baseproperties -contains $object.name) { }
                            else {
                                $baseproperties.add($object.name) | out-null
                            }

                            # For some entries a property can appear in ExtendedProperties and as a normal property
                            # We need to deal with this situation
                            try {
                                # Now add the entry from extendedproperties to the overall properties list
                                $processedentry | Add-Member -MemberType NoteProperty -Name $object.name -Value $object.value -ErrorAction SilentlyContinue
                            }
                            catch {
                                if ((($error[0].FullyQualifiedErrorId).split(",")[0]) -eq "MemberAlreadyExists") { }
                            }
                        }

                        # Convert our extended properties into a string and add that just for fidelity
                        # null the output string
                        [string]$epstring = $null

                        # Convert into a string that is , seperated but with : seperating name and value
                        foreach ($ep in $entry.extendedproperties) {
                            [string]$epstring += $ep.name + ":" + $ep.v + ","
                        }

                        # We also still want to add extendedproperties in as is just for fidelity
                        $processedentry | Add-Member -MemberType NoteProperty -Name ExtendedProperties -Value ($epstring.TrimEnd(","))
                    }
                }
                # Need to convert this from a system object into a string
                # This is an initial pass at this might be a better way to do it
                Actor {
                    if ($null -eq $entry.actor) { }
                    else {
                        # null the output string
                        [string]$actorstring = $null

                        # Convert into a string that is , seperated but with : seperating ID and type
                        foreach ($actor in $entry.actor) {
                            [string]$actorstring += $actor.id + ":" + $actor.type + ","
                        }

                        # Add the string to the output
                        $processedentry | Add-Member -MemberType NoteProperty -Name "Actor" -Value ($actorstring.TrimEnd(","))
                    }
                }
                Target {
                    if ($null -eq $entry.target) { }
                    else {
                        # null the output string
                        [string]$targetstring = $null

                        # Convert into a string that is , seperated but with : seperating ID and type
                        foreach ($target in $entry.target) {
                            [string]$targetstring += $target.id + ":" + $target.type + ","
                        }

                        # Add the string to the output
                        $processedentry | Add-Member -MemberType NoteProperty -Name "Target" -Value ($targetstring.TrimEnd(","))
                    }
                }
                Creationtime {
                    $processedentry | Add-Member -MemberType NoteProperty -Name CreationTime -value (get-date $entry.Creationtime -format g)
                }
                Default {
                    # For some entries a property can appear in ExtendedProperties and as a normal property
                    # We need to deal with this situation
                    try {
                        # Now add the entry from extendedproperties to the overall properties list
                        $processedentry | Add-Member -MemberType NoteProperty -Name $member.name -Value $entry.($member.name) -ErrorAction SilentlyContinue
                    }
                    catch {
                        if ((($error[0].FullyQualifiedErrorId).split(",")[0]) -eq "MemberAlreadyExists") { }
                    }
                }
            }
        }

        # Increment our counter
        $i++

        # Add to output object
        $Listoutput.add($processedentry) | Out-Null
    }

    Write-Progress -Completed -Activity "Converting Json Entries" -Status " "

    # Build a base object using all unique property names
    $baseobject = $null
    $baseobject = New-Object -TypeName PSobject
    foreach ($propertyname in $baseproperties) {
        switch ($propertyname) {
            CreationTime { $baseobject | Add-Member -MemberType NoteProperty -Name $propertyname -Value (get-date 01/01/1900 -format g) }
            Default { $baseobject | Add-Member -MemberType NoteProperty -Name $propertyname -Value "Base" }
        }
    }

    # Add that object to the output
    $Listoutput.add($baseobject) | Out-Null

    # Base object HAS to be the first entry in the output so that when it is written to CSV it includes all properties
    [array]$sortedoutput = $Listoutput | Sort-Object -Property creationtime
    $sortedoutput = $sortedoutput | Where-Object { $_.ClientIP -ne 'Base' }

    # Build an ordered arry to use to order the output coloums
    # Key coloums that we want ordered at the begining of the output
    [array]$baseorder = "CreationTime", "UserId", "Workload", "ClientIP", "CountryName", "KnownMicrosoftIP"

    foreach ($coloumheader in $baseorder) {
        # If the coloum header exists as one of our base properties then add to to coloumorder array and remove from baseproperties list
        if ($baseproperties -contains $coloumheader) {
            [array]$coloumorder += $coloumheader
            $baseproperties.remove($coloumheader)
        }
        else { }
    }

    # Add all of the remaining base properties to the sort order array
    [array]$coloumorder += $baseproperties

    $sortedoutput = $sortedoutput | Select-Object $coloumorder

    # write-host $baseproperties
    return $sortedoutput
}