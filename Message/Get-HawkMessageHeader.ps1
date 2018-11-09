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
        Out-LogFile "Unable to log outlook com object." -error
        Out-Logfile "Please make sure outlook is installed." -error
        Out-logfile $Error[0]
        
        Write-Error "Unable to create Outlook Com Object, please ensure outlook is installed" -ErrorAction Stop
        
    }
    
    # check to see if we have a valid file path
    if (test-path $Emlfile)
    {
        Out-LogFile ("Reading message header from file " + $Emlfile) -action
        # Import the message and start processing the header
        $msg = $ol.CreateItemFromTemplate($Emlfile)
        $header = $msg.PropertyAccessor.GetProperty("http://schemas.microsoft.com/mapi/proptag/0x007D001E")
        $headersWithLines = $header.split("`n")
    }
    else 
    {
        # If we don't have a valid file path log an error and stop
        Out-logfile ("Failed to find file " + $emlfile) -error
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
    

    Return $Output
}