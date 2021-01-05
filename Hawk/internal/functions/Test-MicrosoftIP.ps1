<#
.SYNOPSIS
    Determine if an IP listed in on the O365 XML list
.DESCRIPTION
    Determine if an IP listed in on the O365 XML list
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
Function Test-MicrosoftIP {
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$IPToTest,
        [Parameter(Mandatory = $true)]
        [string]$Type
    )

    # Check if we have imported all of our IP Addresses
    if ($null -eq $MSFTIPList) {
        Out-Logfile "Building MSFTIPList"

        # Load our networking dll pulled from https://github.com/lduchosal/ipnetwork
        [string]$dll = join-path (Split-path (((get-module Hawk)[0]).path) -Parent) "System.Net.IPNetwork.dll"

        $Error.Clear()
        Out-LogFile ("Loading Networking functions from " + $dll)
        [Reflection.Assembly]::LoadFile($dll)

        if ($Error.Count -gt 0) {
            Out-Logfile "[WARNING] - DLL Failed to load can't process IPs"
            Return "Unknown"
        }

        $Error.clear()
        # Read in the XML file from the internet
        # Out-LogFile ("Reading XML for MSFT IP Addresses https://support.content.office.net/en-us/static/O365IPAddresses.xml")
        # [xml]$msftxml = (Invoke-webRequest -Uri https://support.content.office.net/en-us/static/O365IPAddresses.xml).content

        $MSFTJSON = (Invoke-WebRequest -uri ("https://endpoints.office.com/endpoints/Worldwide?ClientRequestId=" + (new-guid).ToString())).content | ConvertFrom-Json

        if ($Error.Count -gt 0) {
            Out-Logfile "[WARNING] - Unable to retrieve JSON file"
            Return "Unknown"
        }

        # Make sure our arrays are null
        [array]$ipv6 = $Null
        [array]$ipv4 = $Null

        # Put all of the IP addresses from the JSON into a simple array
        Foreach ($Entry in $MSFTJSON) {
            $IPList += $Entry.IPs
        }

        # Throw out duplicates
        $IPList = $IPList | Select-Object -Unique

        # Add the IP Addresses into either the v4 or v6 arrays
        Foreach ($ip in $IPList) {
            if ($ip -like "*.*") {
                $ipv4 += $ip
            }
            else {
                $ipv6 += $ip
            }
        }

        Out-LogFile ("Found " + $ipv6.Count + " unique MSFT IPv6 address ranges")
        Out-LogFile ("Found " + $ipv4.count + " unique MSFT IPv4 address ranges")

        # New up using our networking dll we need to pull these all in as network objects
        foreach ($ip in $ipv6) {
            [array]$ipv6objects += [System.Net.IPNetwork]::Parse($ip)
        }
        foreach ($ip in $ipv4) {
            [array]$ipv4objects += [System.Net.IPNetwork]::Parse($ip)
        }

        # Now create our output object
        $output = $Null
        $output = New-Object -TypeName PSObject
        $output | Add-Member -MemberType NoteProperty -Value $ipv6objects -Name IPv6Objects
        $output | Add-Member -MemberType NoteProperty -Value $ipv4objects -Name IPv4Objects

        # Create a global variable to hold our IP list so we can keep using it
        Out-LogFile "Creating global variable `$MSFTIPList"
        New-Variable -Name MSFTIPList -Value $output -Scope global
    }

    # Determine if we have an ipv6 or ipv4 address
    if ($Type -like "ipv6") {

        # Compare to the IPv6 list
        [int]$i = 0
        [int]$count = $MSFTIPList.ipv6objects.count - 1
        # Compare each IP to the ip networks to see if it is in that network
        # If we get back a True or we are beyond the end of the list then stop
        do {
            # Test the IP
            $parsedip = [System.Net.IPAddress]::Parse($IPToTest)
            $test = [System.Net.IPNetwork]::Contains($MSFTIPList.ipv6objects[$i], $parsedip)
            $i++
        }
        until(($test -eq $true) -or ($i -gt $count))

        # Return the value of test true = in MSFT network
        Return $test
    }
    else {
        # Compare to the IPv4 list
        [int]$i = 0
        [int]$count = $MSFTIPList.ipv4objects.count - 1

        # Compare each IP to the ip networks to see if it is in that network
        # If we get back a True or we are beyond the end of the list then stop
        do {
            # Test the IP
            $parsedip = [System.Net.IPAddress]::Parse($IPToTest)
            $test = [System.Net.IPNetwork]::Contains($MSFTIPList.ipv4objects[$i], $parsedip)
            $i++
        }
        until(($test -eq $true) -or ($i -gt $count))

        # Return the value of test true = in MSFT network
        Return $test
    }
}
