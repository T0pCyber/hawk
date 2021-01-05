<#
.SYNOPSIS
    Sends the output of a cmdlet to a txt file and a clixml file
.DESCRIPTION
    Sends the output of a cmdlet to a txt file and a clixml file
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
Function Out-MultipleFileType {
    param
    (
        [Parameter (ValueFromPipeLine = $true)]
        $Object,
        [Parameter (Mandatory = $true)]
        [string]$FilePrefix,
        [string]$User,
        [switch]$Append = $false,
        [switch]$xml = $false,
        [Switch]$csv = $false,
        [Switch]$txt = $false,
        [Switch]$Notice

    )

    begin {

        # If no file types were specified then we need to error out here
        if (($xml -eq $false) -and ($csv -eq $false) -and ($txt -eq $false)) {
            Out-LogFile "[ERROR] - No output type specified on object"
            Write-Error -Message "No output type specified on object" -ErrorAction Stop
        }

        # Null out our array
        [array]$AllObject = $null

        # Set the output path
        if ([string]::IsNullOrEmpty($User)) {
            $path = join-path $Hawk.filepath "\Tenant"
            # Test the path if it is there do nothing otherwise create it
            if (test-path $path) { }
            else {
                Out-LogFile ("Making output directory for Tenant " + $Path)
                $Null = New-Item $Path -ItemType Directory
            }
        }
        else {
            $path = join-path $Hawk.filepath $user

            # Set a bool so we know this is a user output
            [bool]$UserOutput = $true
            # Build short name of user so that it is easier to read
            [string]$ShortUser = ($User.split('@'))[0]

            # Test the path if it is there do nothing otherwise create it
            if (test-path $path) { }
            else {
                Out-LogFile ("Making output directory for user " + $Path)
                $Null = New-Item $Path -ItemType Directory
            }
        }

    }

    process {
        # Collect up all of the incoming data into a single object for processing and output
        [array]$AllObject = $AllObject + $Object

    }

    end {
        if ($null -eq $AllObject) {
            Out-LogFile "No Data Found"
        }
        else {

            # Determine what file type or types we need to write this object into and output it
            # Output XML File
            if ($xml -eq $true) {
                # lets put the xml files in a seperate directory to not clutter things up
                $xmlpath = Join-path $Path XML
                if (Test-path $xmlPath) { }
                else {
                    Out-LogFile ("Making output directory for xml files " + $xmlPath)
                    $null = New-Item $xmlPath -ItemType Directory
                }

                # Build the file name and write it out
                if ($UserOutput) {
                    $filename = Join-Path $xmlpath ($FilePrefix + "_" + $ShortUser + ".xml")
                }
                else {
                    $filename = Join-Path $xmlPath ($FilePrefix + ".xml")
                }
                Out-LogFile ("Writing Data to " + $filename)

                # Output our objects to clixml
                $AllObject | Export-Clixml $filename

                # If notice is set we need to write the file name to _Investigate.txt
                if ($Notice) { Out-LogFile -string ($filename) -silentnotice }
            }

            # Output CSV file
            if ($csv -eq $true) {
                # Build the file name
                if ($UserOutput) {
                    $filename = Join-Path $Path ($FilePrefix + "_" + $ShortUser + ".csv")
                }
                else {
                    $filename = Join-Path $Path ($FilePrefix + ".csv")
                }

                # If we have -append then append the data
                if ($append) {

                    Out-LogFile ("Appending Data to " + $filename)

                    # Write it out to csv making sture to append
                    $AllObject | Export-Csv $filename -NoTypeInformation -Append
                }

                # Otherwise overwrite
                else {
                    Out-LogFile ("Writing Data to " + $filename)
                    $AllObject | Export-Csv $filename -NoTypeInformation
                }

                # If notice is set we need to write the file name to _Investigate.txt
                if ($Notice) { Out-LogFile -string ($filename) -silentnotice }
            }

            # Output Text files
            if ($txt -eq $true) {
                # Build the file name
                if ($UserOutput) {
                    $filename = Join-Path $Path ($FilePrefix + "_" + $ShortUser + ".txt")
                }
                else {
                    $filename = Join-Path $Path ($FilePrefix + ".txt")
                }

                # If we have -append then append the data
                if ($Append) {
                    Out-LogFile ("Appending Data to " + $filename)
                    $AllObject | Format-List * | Out-File $filename -Append
                }

                # Otherwise overwrite
                else {
                    Out-LogFile ("Writing Data to " + $filename)
                    $AllObject | Format-List * | Out-File $filename
                }

                # If notice is set we need to write the file name to _Investigate.txt
                if ($Notice) { Out-LogFile -string ($filename) -silentnotice }
            }
        }
    }

}