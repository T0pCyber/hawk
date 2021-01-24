<#
.SYNOPSIS
    Returns a collection of unique objects filtered by a single property
.DESCRIPTION
    Returns a collection of unique objects filtered by a single property
.PARAMETER ObjectArray
    Array of objects
.PARAMETER Property
    Property of the collection of unique objects
.EXAMPLE
    Select-UniqueObject
    Selects unique objects for investigation
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
Function Select-UniqueObject {
    param
    (
        [Parameter(Mandatory = $true)]
        [array]$ObjectArray,
        [Parameter(Mandatory = $true)]
        [string]$Property
    )

    # Null out our output array
    [array]$Output = $null

    # Get the ID of the unique objects based on the sort property
    [array]$UniqueObjectID = $ObjectArray | Select-Object -Unique -ExpandProperty $Property

    # Select the whole object based on the unique names found
    foreach ($Name in $UniqueObjectID) {
        [array]$Output = $Output + ($ObjectArray | Where-Object { $_.($Property) -eq $Name } | Select-Object -First 1)
    }

    return $Output

}