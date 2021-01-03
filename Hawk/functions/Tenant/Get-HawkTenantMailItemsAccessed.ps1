Function Get-HawkTenantMailItemsAccessed {
    <#
    .SYNOPSIS
        This will export MailboxItemsAccessed operations from the Unified Audit Log (UAL). Must be connected to Exchange Online
        using the Connect-EXO or Connect-ExchangeOnline module. M365 E5 or G5 license is required for this function to work.
        This telemetry will ONLY be availabe if Advanced Auditing is enabled for the M365 tenant.
    .DESCRIPTION
        Recent attacker activities have illuminated the use of the Graph API to read user mailbox contents. This will export
        logs that will be present if the attacker is using the Graph API for such actions. Note: NOT all graph API actions against
        a mailbox are malicious. Review the results of this function and look for Application IDs that are associated with a
        suspicious application ID.
    .EXAMPLE
        PS C:\>Get-HawkTenantMailItemsAccessed
    .OUTPUTS

    .LINK
        https://www.microsoft.com/security/blog/2020/12/21/advice-for-incident-responders-on-recovery-from-systemic-identity-compromises/

    .NOTES

    #>
    [cmdletbinding()]
    param(
        [parameter(Mandatory)]
        [string]$ApplicationID

    )
BEGIN {
    Out-LogFile "Starting Unified Audit Log (UAL) search for 'MailItemsAccessed'"

}#End Begin

PROCESS{
    $MailboxItemsAccessed = Get-AllUnifiedAuditLogEntry -UnifiedSearch ("Search-UnifiedAuditLog -Operations 'MailItemsAccessed' -FreeText $ApplicationID ")

    $MailboxItemsAccessed | Select-Object -ExpandProperty AuditData | Convertfrom-Json | Out-MultipleFileType -FilePrefix "MailItemsAccessed" -csv
}#End Process

END{

    Out-Logfile "Completed exporting MailItemsAccessed logs"
}#End End


}#End Function