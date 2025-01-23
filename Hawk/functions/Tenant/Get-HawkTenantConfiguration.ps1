Function Get-HawkTenantConfiguration {
<#
.SYNOPSIS
	Gather basic tenant configuration and saves the output to a text file
.DESCRIPTION
	Gather basic tenant configuration and saves the output to a text file
	Gathers information about tenant wide settings
	* Admin Audit Log Configuration
	* Organization Configuration
	* Remote domains
	* Transport Rules
	* Transport Configuration
.EXAMPLE
	PS C:\> Get-HawkTenantConfiguration
	Explanation of what the example does
.INPUTS
	Inputs (if any)
.OUTPUTS
	File: AdminAuditLogConfig.txt
	Path: \
	Description: Output of Get-AdminAuditlogConfig

	File: AdminAuditLogConfig.xml
	Path: \XML
	Description: Output of Get-AdminAuditlogConfig as CLI XML

	File: OrgConfig.txt
	Path: \
	Description: Output of Get-OrganizationConfig

	File: OrgConfig.xml
	Path: \XML
	Description: Output of Get-OrganizationConfig as CLI XML

	File: RemoteDomain.txt
	Path: \
	Description: Output of Get-RemoteDomain

	File: RemoteDomain.xml
	Path: \XML
	Description: Output of Get-RemoteDomain as CLI XML

	File: TransportRules.txt
	Path: \
	Description: Output of Get-TransportRule

	File: TransportRules.xml
	Path: \XML
	Description: Output of Get-TransportRule as CLI XML

	File: TransportConfig.txt
	Path: \
	Description: Output of Get-TransportConfig

	File: TransportConfig.xml
	Path: \XML
	Description: Output of Get-TransportConfig as CLI XML
.NOTES
	TODO: Put in some analysis ... flag some key things that we know we should
#>

    # Check if Hawk object exists and is fully initialized
    if (Test-HawkGlobalObject) {
        Initialize-HawkGlobalObject
    }


	Test-EXOConnection
	Send-AIEvent -Event "CmdRun"

    #Check Audit Log Config Setting and make sure it is enabled
    Out-LogFile "Gathering Tenant Configuration Information" -action

    Out-LogFile "Gathering Admin Audit Log" -action
    Get-AdminAuditLogConfig | Out-MultipleFileType -FilePrefix "AdminAuditLogConfig" -txt

    Out-LogFile "Gathering Organization Configuration" -action
    Get-OrganizationConfig| Out-MultipleFileType -FilePrefix "OrgConfig" -txt

    Out-LogFile "Gathering Remote Domains" -action
    Get-RemoteDomain | Out-MultipleFileType -FilePrefix "RemoteDomain" -csv -json

    Out-LogFile "Gathering Transport Rules" -action
    Get-TransportRule | Out-MultipleFileType -FilePrefix "TransportRules" -csv -json

    Out-LogFile "Gathering Transport Configuration" -action
    Get-TransportConfig | Out-MultipleFileType -FilePrefix "TransportConfig" -csv -json
}