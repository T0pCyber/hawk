Function Get-HawkMessageHeader {
    <#
 
	.SYNOPSIS
	Gathers the header from the an msg file prepares a report

	.DESCRIPTION
    Gathers the header from the an msg file prepares a report
    
    For Best Results:
    * Capture a message which was sent from the bad actor to an internal user.
    * Get a copy of the message from the internal user's mailbox.
    * For transfering the file ensure that the source msg is zipped before emailing.
    * On Recieve the admin should extract the MSG and run this cmdlet against it.

    .PARAMETER MSGFile
	Path to an export MSG file.
	
	.OUTPUTS
    File: Message_Header.csv
	Path: \<message name>
    Description: Message Header in CSV form
    
    File: Message_Header_RAW.txt
	Path: \<message name>
	Description: Raw header sutible for going into other tools

	.EXAMPLE
	Get-HawkMessageHeader -msgfile 'c:\temp\my suspicious message.msg'

	Pulls the header and reviews critical information
	
    #>
    
    param
    (
        [Parameter(Mandatory = $true)]
        [string]$MSGFile	
    )

    # Create the outlook com object
    try {
        $ol = New-Object -ComObject Outlook.Application
    }
    catch [System.Runtime.InteropServices.COMException] {
        # If we throw a com expection most likely reason is outlook isn't installed
        Out-LogFile "Unable to create outlook com object." -error
        Out-LogFile "Please make sure outlook is installed." -error
        Out-LogFile $Error[0]
        
        Write-Error "Unable to create Outlook Com Object, please ensure outlook is installed" -ErrorAction Stop
        
    }

    # Create the Hawk object if it isn't there already
    Initialize-HawkGlobalObject
    Send-AIEvent -Event "CmdRun"

    
    # check to see if we have a valid file path
    if (Test-Path $MSGFile) {
        
        # Convert a possible relative path to a full path
        $MSGFile = (Resolve-Path $MSGFile).Path

        # Store the file name for later use
        $MSGFileName = $MSGFile | Split-Path -Leaf
        
        Out-LogFile ("Reading message header from file " + $MSGFile) -action
        # Import the message and start processing the header
        try {
            $msg = $ol.CreateItemFromTemplate($MSGFile)
            $header = $msg.PropertyAccessor.GetProperty("http://schemas.microsoft.com/mapi/proptag/0x007D001E")
        }
        catch {
            Out-LogFile ("Unable to load " + $MSGFile)
            Out-LogFile $Error[0]
            break
        }

        $headersWithLines = $header.split("`n")
    }
    else {
        # If we don't have a valid file path log an error and stop
        Out-LogFile ("Failed to find file " + $MSGFile) -error
        Write-Error -Message "Failed to find file " + $MSGFile -ErrorAction Stop
    }
        
    # Make sure variables are empty
    [string]$CombinedString = $null
    [array]$Output = $null

    # Read thru each line to pull together each entry into a single object
    foreach ($string in $headersWithLines) {
        # If our string is not null and we have a leading whitespace then this needs to be added to the previous string as part of the same object.
        if (!([string]::IsNullOrEmpty($string)) -and ([char]::IsWhiteSpace($string[0]))) {
            # Do some string clean up 
            $string = $string.trimstart()
            $string = $string.trimend()
            $string = " " + $string

            # Push the string together
            [string]$CombinedString += $string
        }
        
        # If we are here we do a null check just in case but we know the first char is not a whitespace
        # So we have a new "object" that we need to process in
        elseif (!([string]::IsNullOrEmpty($string))) {
            
            # For the inital pass the string will be null or empty so we need to check for that
            if ([string]::IsNullOrEmpty($CombinedString)) {
                # Create our new string and continue processing
                $CombinedString = ($string.trimend())
            }
            else {
                # We should have everything now so create the object
                $Object = $null
                $Object = New-Object -TypeName PSObject
                
                # Split the string on the divider and add it to the object
                [array]$StringSplit = $CombinedString -split ":", 2
                $Object | Add-Member -MemberType NoteProperty -Name "Header" -Value $StringSplit[0].trim()
                $Object | Add-Member -MemberType NoteProperty -Name "Value" -Value $StringSplit[1].trim()

                # Add to the output array
                [array]$Output += $Object

                # Create our new string and continue processing
                $CombinedString = $string.trimend()
            }            
        }
        else { }
    }

    # Now that we have the header objects in an array we can work on them and output a report
    $receivedHeadersString = $null
    $receivedHeadersObject = $null

    # Null out the output
    [array]$Findings = $null

    # Determine the initial submitting client/ip

    [array]$receivedHeadersString = $Output | Where-Object { $_.header -eq "Received" }
    foreach ($stringHeader in $receivedHeadersString.value) {
        [array]$receivedHeadersObject += Convert-ReceiveHeader -Header $stringHeader
    }

    # Sort the receive header so oldest is at the top
    $receivedHeadersObject = $receivedHeadersObject | Sort-Object -Property ReceivedFromTime

    if ($null -eq $receivedHeadersObject) { }
    else {

        # Determine how it was submitted to the service
        if ($receivedHeadersObject[0].ReceivedBy -like "*outlook.com*") {
            $Findings += (Add-Finding -Name "Submitting Host" -Value $receivedHeadersObject[0].ReceivedBy -Conclusion "Submitted from Office 365" -MoreInformation "Warning - This might have originated from one of your clients")
        }
        else {
            $Findings += (Add-Finding -Name "Submitting Host" -Value $receivedHeadersObject[0].ReceivedBy -Conclusion "Submitted from Internet" -MoreInformation "")
        }

        ### Output to the report the client that submitted
        $Findings += (Add-Finding -Name "Submitting Client" -Value $receivedHeadersObject[0].ReceivedWith -Conclusion "None" -MoreInformation "")
    }
    
    ### Output the AuthAS type
    $AuthAs = $output | Where-Object { $_.header -like 'X-MS-Exchange-Organization-AuthAs' }
    # Make sure we got something back
    if ($null -eq $AuthAs) { }
    else {
        # If auth is anonymous then it came from the internet
        if ($AuthAs.value -eq "Anonymous") {
            $Findings += (Add-Finding -Name "Authentication Method" -Value $AuthAs.value -Conclusion "Method used to authenticate" -MoreInformation "https://docs.microsoft.com/en-us/exchange/header-firewall-exchange-2013-help")
        }
        else {
            $Findings += (Add-Finding -Name "Authentication Method" -Value $AuthAs.value -Conclusion "Method used to authenticate" -MoreInformation "https://docs.microsoft.com/en-us/exchange/header-firewall-exchange-2013-help")
        }
    }
    
    ### Determine the AuthMechanism
    $AuthMech = $output | Where-Object { $_.header -like 'X-MS-Exchange-Organization-AuthMechanism' }
    # Make sure we got something back
    if ($null -eq $AuthMech) { }
    else {
        # If auth is anonymous then it came from the internet
        if ($AuthMech.value -eq "04" -or $AuthMech.value -eq "06") {
            $Findings += (Add-Finding -Name "Authentication Mechanism" -Value $AuthMech.value -Conclusion "04 = Credentials Used; 06 = SMTP Authentication" -MoreInformation "https://docs.microsoft.com/en-us/exchange/header-firewall-exchange-2013-help")
        }
        else {
            $Findings += (Add-Finding -Name "Authentication Mechanism" -Value $AuthMech.value -Conclusion "Mechanism used to authenticate" -MoreInformation "https://docs.microsoft.com/en-us/exchange/header-firewall-exchange-2013-help")
        }
    }

    ### Do P1 and P2 match
    $From = $output | Where-Object { $_.header -like 'From' }    
    $ReturnPath = $output | Where-Object { $_.header -like 'Return-Path' }

    # Pull out the from string since it can be formatted with a name
    $frommatches = $null
    $frommatches = $From.Value | Select-String -Pattern '(?<=<)([\s\S]*?)(?=>)' -AllMatches

    if ($null -ne $frommatches) {
        # Pull the string from the matches
        [string]$fromString = $frommatches.Matches.Groups[1].Value
    }
    else {
        [string]$fromString = $From.value
    }

    # Check to see if they match
    if ($fromString.trim() -eq $ReturnPath.value.trim()) {
        $Findings += (Add-Finding -Name "P1 P2 Match" -Value ("From: " + $From.value + ";  Return-Path: " + $ReturnPath.value) -Conclusion "P1 and P2 Header match" -MoreInformation "")
    }
    else {
        $Findings += (Add-Finding -Name "P1 P2 Match" -Value ("From: " + $From.value + ";  Return-Path: " + $ReturnPath.value) -Conclusion "P1 and P2 Header don't Match" -MoreInformation "WARNING - P1 and P2 Header don't Match")
    }

    # Output the Findings
    $Findings | Out-MultipleFileType -FilePrefix "Message_Header_Findings" -user $MSGFileName -csv

    # Output everything to a file
    $Output | Out-MultipleFileType -FilePrefix "Message_Header" -User $MSGFileName -csv

    # Output the RAW Header to the file for use in other tools
    $header | Out-MultipleFileType -FilePrefix "Message_Header_RAW" -user $MSGFileName -txt
}


# Function to create a finding object for adding to the output array
Function Add-Finding {
    param (
        [string]$Name,
        [string]$Value,
        [string]$Conclusion,
        [string]$MoreInformation
    )

    # Create the object
    $Obj = New-Object PSObject

    # Added the needed properties
    $Obj | Add-Member -MemberType NoteProperty -Name "Rule" -Value $Name
    $Obj | Add-Member -MemberType NoteProperty -Name "Value" -Value $Value
    $Obj | Add-Member -MemberType NoteProperty -Name "Conclusion" -Value $Conclusion
    $Obj | Add-Member -MemberType NoteProperty -Name "More Information" -Value $MoreInformation

    # Return the object
    Return $Obj

}

# Processing a received header and returns it as a object
Function Convert-ReceiveHeader {
    #Core code from https://blogs.technet.microsoft.com/heyscriptingguy/2011/08/18/use-powershell-to-parse-email-message-headerspart-1/
    Param
    (
        [Parameter(Mandatory = $true)]
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
    if ($null -ne $headerMatches) {
        # Formatch our with
        Switch -wildcard ($headerMatches.Matches.groups[3].value.trim()) {
            "SMTP*" { $with = "SMTP" }
            "ESMTP*" { $with = "ESMTP" }
            default { $with = $headerMatches.Matches.groups[3].value.trim() }
        }
        
        # Create the hash to generate the output object
        $fromhash = @{
            ReceivedFrom = $headerMatches.Matches.groups[1].value.trim()
            ReceivedBy   = $headerMatches.Matches.groups[2].value.trim()
            ReceivedWith = $with
            ReceivedTime = [datetime]($headerMatches.Matches.groups[4].value.trim())
        }                 
        
        # Put the data into an object and return it
        $Output = New-Object -TypeName PSObject -Property $fromhash                  
        return $Output
    }
    # If we failed to match then return null
    else {
        return $null
    }
}