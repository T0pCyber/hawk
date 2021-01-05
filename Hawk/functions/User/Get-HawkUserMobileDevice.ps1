Function Get-HawkUserMobileDevice {
    <#
 
	.SYNOPSIS
	Gathers mobile devices that are connected to the account

	.DESCRIPTION
    Pulls all mobile devices attached to them mailbox using get-mobiledevice

    If any devices had their first sync inside of the investigation window it will flag them.
    Investigator should follow up on these devices

	.PARAMETER UserPrincipalName
	Single UPN of a user, commans seperated list of UPNs, or array of objects that contain UPNs.

	.OUTPUTS
	
	File: MobileDevices.csv
	Path: \<User>
    Description: All mobile devices attached to the mailbox
    
    File: _Investigate_MobileDevice.csv
    Path: \<User>
    Descriptoin: Any devices that were found to have their first sync inside of the investigation window
	
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
                if ($Device.FirstSyncTime -gt $Hawk.StartDate){
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
