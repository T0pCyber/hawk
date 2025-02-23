Function Get-HawkUserMailSendActivity {
    <#
    .SYNOPSIS
        This will export Send operations from the Unified Audit Log (UAL). Must be connected to Exchange Online
        using the Connect-EXO or Connect-ExchangeOnline module. M365 E5 or G5 license is required for this function to work.
        This telemetry will ONLY be availabe if Advanced Auditing is enabled for the M365 user.
    .DESCRIPTION
        This function queries for message-sending activity within Exchange, providing visibility into outbound communications
        that could be relevant for identifying data exfiltration attempts, phishing campaigns, or other malicious activity.
    .PARAMETER UserPrincipalName
        Specific user(s) to be investigated
    .EXAMPLE
        Get-HawkUserMailSendActivity -UserPrincipalName bsmith@contoso.com
        Returns send activity queries from Unified Audit Log (UAL) that correspond to the UserPrincipalName that is provided
    .OUTPUTS
        SendActivity_bsmith@contoso.com.csv /json
        Simple_SendActivity_bsmith@contoso.com.csv/json

    .LINK
        https://www.microsoft.com/security/blog/2020/12/21/advice-for-incident-responders-on-recovery-from-systemic-identity-compromises/

    .NOTES
        "Operation Properties" and "Folders" will return "System.Object" as they are nested JSON within the AuditData field.
        You will need to conduct individual log pull and review via PowerShell or other SIEM to determine values
        for those fields.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$UserPrincipalName
    )

    BEGIN {
        # Check if Hawk object exists and is fully initialized
        if (Test-HawkGlobalObject) {
            Initialize-HawkGlobalObject
        }
        Test-EXOConnection
        Send-AIEvent -Event "CmdRun"
    }#End Begin

    PROCESS {

        #Verify UPN input
        [array]$UserArray = Test-UserObject -ToTest $UserPrincipalName

        foreach ($UserObject in $UserArray) {
            [string]$User = $UserObject.UserPrincipalName

            Out-LogFile "Initiating collection of mail 'Send' logs for $User from the UAL." -Action
            Out-LogFile "Please be patient, this can take a while..." -Information

            # Verify that user has operation enabled for auditing. Otherwise, move onto next user.
            if (Test-OperationEnabled -User $User -Operation 'Send') {
                Out-LogFile "Operation 'Send' verified enabled for $User." -Information
                try {
                    #Retrieve all audit data for Exchange send activity
                    $SearchCommand = "Search-UnifiedAuditLog -Operations 'Send' -UserIds $User"
                    $ExchangeSends = Get-AllUnifiedAuditLogEntry -UnifiedSearch $SearchCommand

                    if ($ExchangeSends.Count -gt 0) {

                        #Define output directory path for user
                        $UserFolder = Join-Path -Path $Hawk.FilePath -ChildPath $User

                        #Create user directory if it doesn't already exist
                        if (-not (Test-Path -Path $UserFolder)) {
                            New-Item -Path $UserFolder -ItemType Directory -Force | Out-Null
                        }

                        #Compress raw data into more simple view
                        $ExchangeSendsSimple = $ExchangeSends | Get-SimpleUnifiedAuditLog

                        #Export both raw and simplistic views to specified user's folder
                        $ExchangeSends | Select-Object -ExpandProperty AuditData | Convertfrom-Json | Out-MultipleFileType -FilePrefix "SendActivity_$User" -User $User -csv -json
                        $ExchangeSendsSimple | Out-MultipleFileType -FilePrefix "Simple_SendActivity_$User" -User $User -csv -json
                    }
                    else {
                        Out-LogFile "No mail 'Send' logs found for $User." -Information
                    }
                }
                catch {
                    Out-LogFile "Error processing Send Activity for $User : $_" -isError
                    Write-Error -ErrorRecord $_ -ErrorAction Continue
                }
            }
            else {
                Out-LogFile "Operation 'Send' is not enabled for $User." -Information
                Out-LogFile "No data recorded for $User." -Information
            }
            Out-LogFile "Completed collection of mail 'Send' logs for $User from the UAL." -Information

        }

    }#End Process

    END {
    }#End End

}