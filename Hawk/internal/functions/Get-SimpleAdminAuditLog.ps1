<#
.SYNOPSIS
    Convert output from search-adminauditlog to be more human readable
.DESCRIPTION
    Convert output from search-adminauditlog to be more human readable
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
Function Get-SimpleAdminAuditLog {
    Param (
        [Parameter(
            Position = 0,
            Mandatory = $true,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)
        ]
        $SearchResults
    )

    # Setup to process incomming results
    Begin {

        # Make sure the array is null
        [array]$ResultSet = $null

    }

    # Process thru what ever is comming into the script
    Process {

        # Deal with each object in the input
        $searchresults | ForEach-Object {

            # Reset the result object
            $Result = New-Object PSObject

            # Get the alias of the User that ran the command
            [string]$user = $_.caller

            # If it is null then replace with *** for admin call
            if ([string]::IsNullOrEmpty($user)) { $user = "***" }

            # if we have 'on behalf of' then we need to do some more processing to get the right value
            elseif ($_.caller -like "*on ehalf of*") {
                $split = $_.caller.split("/")
                $Start = (($Split[3].split(" "))[0]).TrimEnd('"')
                $End = $Split[-1].trimend('"')

                [string]$User = $Start + " on behalf of " + $end
            }
            # If there is a / in the username lests simply it
            elseif ($_.caller -contains "/") {
                [string]$user = ($_.caller.split("/"))[-1]
            }
            # If none of the above or true just pass it thru
            else {
                [string]$user = $_.caller
            }

            # Build the command that was run
            $switches = $_.cmdletparameters
            [string]$FullCommand = $_.cmdletname

            # Get all of the switchs and add them in "human" form to the output
            foreach ($parameter in $switches) {

                # Format our values depending on what they are so that they are as close
                # a match as possible for what would have been entered
                switch -regex ($parameter.value) {

                    # If we have a multi value array put in then we need to break it out and add quotes as needed
                    '[;]'	{

                        # Reset the formatted value string
                        $FormattedValue = $null

                        # Split it into an array
                        $valuearray = $switch.current.split(";")

                        # For each entry in the array add quotes if needed and add it to the formatted value string
                        $valuearray | ForEach-Object {
                            if ($_ -match "[ \t]") { $FormattedValue = $FormattedValue + "`"" + $_ + "`";" }
                            else { $FormattedValue = $FormattedValue + $_ + ";" }
                        }

                        # Clean up the trailing ;
                        $FormattedValue = $FormattedValue.trimend(";")

                        # Add our switch + cleaned up value to the command string
                        $FullCommand = $FullCommand + " -" + $parameter.name + " " + $FormattedValue
                    }

                    # If we have a value with spaces add quotes
                    '[ \t]' { $FullCommand = $FullCommand + " -" + $parameter.name + " `"" + $switch.current + "`"" }

                    # If we have a true or false format them with :$ in front ( -allow:$true )
                    '^True$|^False$'	{ $FullCommand = $FullCommand + " -" + $parameter.name + ":`$" + $switch.current }

                    # Otherwise just put the switch and the value
                    default { $FullCommand = $FullCommand + " -" + $parameter.name + " " + $switch.current }

                }
            }

            # Format our modified object
            if ([string]::IsNullOrEmpty($_.objectModified)) { $ObjModified = "" }
            else {
                $ObjModified = ($_.objectmodified.split("/"))[-1]
                $ObjModified = ($ObjModified.split("\"))[-1]
            }

            # Get just the name of the cmdlet that was run
            [string]$cmdlet = $_.CmdletName

            # Build the result object to return our values
            $Result | Add-Member -MemberType NoteProperty -Value $user -Name Caller
            $Result | Add-Member -MemberType NoteProperty -Value $cmdlet -Name Cmdlet
            $Result | Add-Member -MemberType NoteProperty -Value $FullCommand -Name FullCommand
            $Result | Add-Member -MemberType NoteProperty -Value ($_.rundate).ToUniversalTime() -Name 'RunDate(UTC)'
            $Result | Add-Member -MemberType NoteProperty -Value $ObjModified -Name ObjectModified

            # Add the object to the array to be returned
            $ResultSet = $ResultSet + $Result

        }
    }

    # Final steps
    End {
        # Return the array set
        Return $ResultSet
    }
}
