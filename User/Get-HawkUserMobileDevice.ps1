Function Get-HawkUserMobileDevice {
    <#
 
	.SYNOPSIS
	Pull that last 7 days of message trace data for the specified user.

	.DESCRIPTION
    Pulls the basic message trace data for the specified user.
    Can only pull the last 7 days as that is all we keep in get-messagetrace

    Further investigation will require Start-HistoricalSearch

	.PARAMETER UserPrincipalName
	Single UPN of a user, commans seperated list of UPNs, or array of objects that contain UPNs.

	.OUTPUTS
	
	File: Message_Trace.csv
	Path: \<User>
	Description: Output of Get-MessageTrace -Sender <primarysmtpaddress>
	
	.EXAMPLE

	Get-HawkUserMessageTrace -UserPrincipalName user@contoso.com

	Gets the message trace for user@contoso.com for the last 7 days

	#>
    
    param
    (
        [Parameter(Mandatory = $true)]
        [array]$UserPrincipalName
	
    )
	
    Test-EXOConnection
    Send-AIEvent -Event "CmdRun"

    # Verify our UPN input
    [array]$UserArray = Test-UserObject -ToTest $UserPrincipalName
	
    # Gather the trace
    foreach ($Object in $UserArray) {

        [string]$User = $Object.UserPrincipalName

        # Get all mobile devices
        Out-Logfile ("Gathering Mobile Devices for: " + $User)
        [array]$MobileDevices = Get-MobileDevice -mailbox $User

        if ($Null -eq $MobileDevices) {
            Out-Logfile ("No devices found for user: " + $User)
        }
        else {
            Out-Logfile ("Found " + $MobileDevices.count + " Devices")

            # Check each device to see if it was NEW
            # If so flag it for investigation
            foreach ($Device in $MobileDevices){
                if ($Device.FirstSyncTime -gt $Hawk.EndDate){
                    Out-Logfile ("Device found that was first synced inside investigation window") -notice
                    Out-LogFile ("DeviceID: " + $Device.DeviceID) -notice
                    $Device | Out-MultipleFileType -FilePreFix "_Investigate_MobileDevice" -user $user -csv -append -Notice
                }
            }

            # Output all devices found
            $MobileDevices | Out-MultipleFileType -FilePreFix "MobileDevices" -user $user -csv
        }
    }
}
