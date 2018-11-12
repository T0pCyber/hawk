Function Get-HawkMessageHeader
{
    param
    (
        [Parameter(Mandatory = $true)]
		[string]$Emlfile	
    )

    # Create the outlook com object
    try 
    {
        $ol = New-Object -ComObject Outlook.Application
    }
    catch [System.Runtime.InteropServices.COMException]
    {
        # If we throw a com expection most likely reason is outlook isn't installed
        Write-Host "Unable to log outlook com object." -error
        Write-Host "Please make sure outlook is installed." -error
        Write-Host $Error[0]
        
        Write-Error "Unable to create Outlook Com Object, please ensure outlook is installed" -ErrorAction Stop
        
    }

    
    # check to see if we have a valid file path
    if (test-path $Emlfile)
    {
        
        # Convert a possible relative path to a full path
        $Emlfile = (Resolve-Path $Emlfile).Path

        # Store the file name for later use
        $EmlfileName = $Emlfile | Split-Path -Leaf
        
        Write-Host ("Reading message header from file " + $Emlfile) -action
        # Import the message and start processing the header
        try 
        {
            $msg = $ol.CreateItemFromTemplate($Emlfile)
            $header = $msg.PropertyAccessor.GetProperty("http://schemas.microsoft.com/mapi/proptag/0x007D001E")
        }
        catch
        {
            Write-Host ("Unable to load " + $Emlfile)
            Write-Host $Error[0]
            break
        }

        $headersWithLines = $header.split("`n")
    }
    else 
    {
        # If we don't have a valid file path log an error and stop
        Write-Host ("Failed to find file " + $emlfile) -error
        Write-Error -Message "Failed to find file " + $emlfile -ErrorAction Stop
    }
        
    # Make sure or variable are empty
    [string]$CombinedString = $null
    [array]$Output = $null

    # Read thru each line to pull together each entry into a single object
    foreach ($string in $headersWithLines)
    {
        # If our string is not null and we have a leading whitespace then this needs to be added to the previous string as part of the same object.
        if (!([string]::IsNullOrEmpty($string)) -and ([char]::IsWhiteSpace($string[0])))
        {
            # Do some string clean up 
            $string = $string.trimstart()
            $string = $string.trimend()
            $string = " " + $string

            # Push the string together
            [string]$CombinedString += $string
        }
        
        # If we are here we do a null check just in case but we know the first char is not a whitespace
        # So we have a new "object" that we need to process in
        elseif (!([string]::IsNullOrEmpty($string))) 
        {
            
            # For the inital pass the string will be null or empty so we need to check for that
            if ([string]::IsNullOrEmpty($CombinedString))
            {
                # Create our new string and continue processing
                $CombinedString = ($string.trimend())
            }
            else 
            {
                # We should have everything now so create the object
                $Object = $null
                $Object = New-Object -TypeName PSObject
                
                # Split the string on the divider and add it to the object
                [array]$StringSplit = $CombinedString -split ":",2
                $Object | Add-Member -MemberType NoteProperty -Name "Header" -Value $StringSplit[0]
                $Object | Add-Member -MemberType NoteProperty -Name "Value" -Value $StringSplit[1]

                # Add to the output array
                [array]$Output += $Object

                # Create our new string and continue processing
                $CombinedString = $string.trimend()
            }            
        }
        else {}
    }

    # Now that we have the header objects in an array we can work on them and output a report
    $receivedHeadersString = $null
    $receivedHeadersObject = $null

    # Determine the initial submitting client/ip
    [array]$receivedHeadersString = $Output | Where-Object {$_.header -eq "Received"}
    foreach ($stringHeader in $receivedHeadersString.value)
    {
        [array]$receivedHeadersObject += Convert-ReceiveHeader -Header $stringHeader
    }

    # Sort the receive header so oldest is at the top
    $receivedHeadersObject = $receivedHeadersObject | Sort-Object -Property ReceivedFromTime

    ### Determine how it was submitted to the service
    if ($receivedHeadersObject[0].ReceivedBy -like "*outlook.com*")
    {
        Out-Report -Identity $EmlfileName -Property "Submitting Host" -Value $receivedHeadersObject[0].ReceivedBy -Description "Submitted from Office 365" -State Warning
    }
    else 
    {
        Out-Report -Identity $EmlfileName -Property "Submitting Host" -Value $receivedHeadersObject[0].ReceivedBy -Description "Submitted from Internet"
    }

    ### Output to the report the client that submitted
    Out-Report -Identity $EmlfileName -Property "Submitting Client" -Value $receivedHeadersObject[0].ReceivedWith -Description "Submitting Client"

    ### Output the AuthAS type
    $AuthAs = $output | Where-Object {$_.header -like 'X-MS-Exchange-Organization-AuthAs'}
    # Make sure we got something back
    if ($null -eq $AuthAs){}
    else 
    {
        # If auth is anonymous then it came from the internet
        if ($AuthAs.value -eq "Anonymous")
        {
            Out-Report -Identity $EmlfileName -Property "Authentication Method" -Value $AuthAs.value -Description "Method used to authenticate" -Link "https://docs.microsoft.com/en-us/exchange/header-firewall-exchange-2013-help"
        }
        else
        {
            Out-Report -Identity $EmlfileName -Property "Authentication Method" -Value $AuthAs.value -Description "Method used to authenticate" -State Warning -link "https://docs.microsoft.com/en-us/exchange/header-firewall-exchange-2013-help"
        }
    }
    
    ### Determine the AuthMechanism
    $AuthMech = $output | Where-Object {$_.header -like 'X-MS-Exchange-Organization-AuthMechanism'}
    # Make sure we got something back
    if ($null -eq $AuthMech){}
    else 
    {
        # If auth is anonymous then it came from the internet
        if ($AuthMech.value -eq "04" -or $AuthMech -eq "06")
        {
            Out-Report -Identity $EmlfileName -Property "Authentication Mechanism" -Value $AuthMech.value -Description "04 is Credentials Used`n06 is SMTP Authentication`nMethod used to authenticate <a href=`"https://docs.microsoft.com/en-us/exchange/header-firewall-exchange-2013-help`">X-MS-Exchange-Organization-AuthAs</a>" -state Warning
        }
        else
        {
            Out-Report -Identity $EmlfileName -Property "Authentication Mechanism" -Value $AuthMech.value -Description "Mechanism used to authenticate" -link "https://docs.microsoft.com/en-us/exchange/header-firewall-exchange-2013-help"
        }
    }

    ### Do P1 and P2 match
    $From = $output | Where-Object {$_.header -like 'From'}    
    $ReturnPath = $output | Where-Object {$_.header -like 'Return-Path'}

    # Pull out the from string since it can be formatted with a name
    $frommatches = $null
    $frommatches = $From.Value | Select-String -Pattern '(?<=<)([\s\S]*?)(?=>)' -AllMatches

    if ($null -ne $frommatches)
    {
        # Pull the string from the matches
        [string]$fromString = $frommatches.Matches.Groups[1].Value
    }
    else 
    {
        [string]$fromString = $From.value
    }

    # Check to see if they match
    if ($fromString.trim() -eq $ReturnPath.value.trim())
    {
        Out-Report -Identity $EmlfileName -Property "P1 P2 Match" -Value ("From: " + $From.value + " Return-Path: " + $ReturnPath.value) -Description "P1 and P2 Header should match"
    }
    else
    {
        Out-Report -Identity $EmlfileName -Property "P1 P2 Match" -Value ("From: " + $From.value + " Return-Path: " + $ReturnPath.value) -Description "P1 and P2 Header don't Match" -state Error
    }

    # Header text path 
    $HeaderOutputPath = Join-path $hawk.filepath ($EmlfileName + "\Message_Header.csv")
    Out-Report -Identity $EmlfileName -Property "Header Path" -Value $HeaderOutputPath -Description "Location of Full Header"

    # Output everything to a file
    $Output | Out-MultipleFileType -FilePrefix "Message_Header" -User $EmlfileName -csv -txt
}


# Processing a received header and returns it as a object
Function Convert-ReceiveHeader
{
    #Core code from https://blogs.technet.microsoft.com/heyscriptingguy/2011/08/18/use-powershell-to-parse-email-message-headerspart-1/
    Param
    (
        [Parameter(Mandatory=$true)]
        [String]$Header
    )

    # Remove any leading spaces from the input text
    $Header = $Header.TrimStart()
    $Header = $Header + " "

    # Create our regular expression for pulling out the sections of the header
    $HeaderRegex = 'from([\s\S]*?)by([\s\S]*?)with([\s\S]*?);([(\s\S)*]{32,36})(?:\s\S*?)'

    # Find out different groups with the regex
    $headerMatches = $Header | Select-String -Pattern $HeaderRegex -AllMatches
    
    # Check if we got back results
    if ($null -ne $headerMatches)
    {
        # Formatch our with
        Switch -wildcard ($headerMatches.Matches.groups[3].value.trim())
        {
            "SMTP*" {$with = "SMTP"}
            "ESMTP*" {$with = "ESMTP"}
            default{$with = $headerMatches.Matches.groups[3].value.trim()}
        }
        
        # Create the hash to generate the output object
        $fromhash = @{
            ReceivedFrom = $headerMatches.Matches.groups[1].value.trim()
            ReceivedBy = $headerMatches.Matches.groups[2].value.trim()
            ReceivedWith = $with
            ReceivedTime = [datetime]($headerMatches.Matches.groups[4].value.trim())
        }                 
        
        # Put the data into an object and return it
        $Output = New-Object -TypeName PSObject -Property $fromhash                  
        return $Output
    }
    # If we failed to match then return null
    else
    {
        return $null
    }
}