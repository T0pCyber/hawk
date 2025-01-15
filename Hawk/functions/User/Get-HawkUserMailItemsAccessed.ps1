Function Get-HawkUserMailItemsAccessed {
<#
.SYNOPSIS
    This will export MailboxItemsAccessed operations from the Unified Audit Log (UAL). Must be connected to Exchange Online
    using the Connect-EXO or Connect-ExchangeOnline module. M365 E5 or G5 license is required for this function to work.
    This telemetry will ONLY be availabe if Advanced Auditing is enabled for the M365 user.
.DESCRIPTION
    Recent attacker activities have illuminated the use of the Graph API to read user mailbox contents. This will export
    logs that will be present if the attacker is using the Graph API for such actions. Note: NOT all graph API actions against
    a mailbox are malicious. Review the results of this function and look for suspicious access of mailbox items associated
    with a specific user.
.PARAMETER UserIDs
    Specific user(s) to be investigated
.EXAMPLE
    Get-HawkUserMailItemsAccessed -UserIDs bsmith@contoso.com
    Gets MailItemsAccessed from Unified Audit Log (UAL) that corresponds to the User ID that is provided
.OUTPUTS
    MailItemsAccessed_bsmith@contoso.com.csv /json
    Simple_MailItemsAccessed.csv/json

.LINK
    https://www.microsoft.com/security/blog/2020/12/21/advice-for-incident-responders-on-recovery-from-systemic-identity-compromises/

.NOTES
    "Operation Properties" and "Folders" will return "System.Object" as they are nested JSON within the AuditData field.
    You will need to conduct individual log pull and review via PowerShell or other SIEM to determine values
    for those fields.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [array]$UserPrincipalName
    )

    BEGIN {
        # Check if Hawk object exists and is fully initialized
        if (Test-HawkGlobalObject) {
            Initialize-HawkGlobalObject
        }
        Out-LogFile "Starting Unified Audit Log (UAL) search for 'MailItemsAccessed'" -Action
        Out-LogFile "Please be patient, this can take a while..." -Action
        Test-EXOConnection
    }#End Begin

    PROCESS {
        
        #Verify UPN input
        [array]$UserArray = Test-UserObject -ToTest $UserPrincipalName

        foreach($UserObject in $UserArray) {
            [string]$User = $UserObject.UserPrincipalName
            try {
                #Retrieve all audit data for mailitems accessed 
                $SearchCommand = "Search-UnifiedAuditLog -Operations 'MailItemsAccessed' -UserIds $User"
                $MailboxItemsAccessed = Get-AllUnifiedAuditLogEntry -UnifiedSearch $SearchCommand
                
                if ($MailboxItemsAccessed.Count -gt 0){
                    
                    #Define output directory path for user
                    $UserFolder = Join-Path -Path $Hawk.FilePath -ChildPath $User

                    #Create user directory if it doesn't already exist
                    if (-not (Test-Path -Path $UserFolder)) {
                        New-Item -Path $UserFolder -ItemType Directory -Force | Out-Null
                    }

                    #Compress raw data into more simple view
                    $MailboxItemsAccessedSimple = $MailboxItemsAccessed | Get-SimpleUnifiedAuditLog

                    #Export both raw and simplistic views to specified user's folder
                    $MailboxItemsAccessed | Select-Object -ExpandProperty AuditData | Convertfrom-Json | Out-MultipleFileType -FilePrefix "MailItemsAccessed_$User" -User $User -csv -json
                    $MailboxItemsAccessedSimple | Out-MultipleFileType -FilePrefix "Simple_MailItemsAccessed_$User" -User $User -csv -json
                } else {
                    Out-LogFile "Get-HawkUserMailItemsAccesed completed successfully" -Information
                    Out-LogFile "No items found for $User." -Information
                }
            } catch {
                Out-LogFile "Error processing mail items accessed for $User : $_" -isError
                Write-Error -ErrorRecord $_ -ErrorAction Continue
            }
        }
        
    }#End Process

    END{
        Out-Logfile "Completed exporting MailItemsAccessed logs" -Information
    }#End End

}