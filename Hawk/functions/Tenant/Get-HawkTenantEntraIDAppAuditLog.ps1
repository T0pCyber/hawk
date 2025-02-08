Function Get-HawkTenantEntraIDAppAuditLog{
<#
.SYNOPSIS
    Retrieves audit logs for application permission and consent events in Microsoft Entra ID.

.DESCRIPTION
    This function searches the Microsoft 365 Unified Audit Log for historical events related to 
    application permissions and consent grants in Microsoft Entra ID (formerly Azure AD). It focuses 
    on tracking when and by whom application permissions were granted or modified.

    Key events tracked:
    - OAuth2 permission grant additions
    - Application consent grants
    - Changes to application permissions

    The function provides historical context to complement Get-HawkTenantConsentGrant, which shows 
    current permission states. While Get-HawkTenantConsentGrant shows what permissions exist now, 
    this function helps you understand how and when those permissions were established.

    The audit data includes:
    - Timestamp of permission changes
    - UserID/UPN of who made the changes
    - Target application details
    - Client IP address of where changes originated
    - Operation details and result status

.OUTPUTS
    File: Entra_ID_Application_Audit.csv/.json
    Path: \Tenant
    Description: Contains all application permission and consent events found in the audit logs with fields for:
    - Id: Unique identifier for the audit event
    - Operation: Type of operation performed (e.g., Add OAuth2PermissionGrant)
    - ResultStatus: Success/failure status of the operation
    - Workload: The workload where the operation occurred
    - ClientIP: IP address where the operation originated
    - UserID: User who performed the operation
    - ActorUPN: UserPrincipalName of the user who performed the action
    - TargetName: Name of the application affected
    - EnvTime: Timestamp of the event
    - CorrelationId: Identifier to correlate related events

.EXAMPLE
    Get-HawkTenantEntraIDAppAuditLog

    Searches the audit logs for all application permission and consent events within the configured 
    time window. Results are exported to Entra_ID_Application_Audit.csv and .json files.

.NOTES
    Author: Jonathan Butler
    Version: 4.0
    

.LINK
    https://learn.microsoft.com/en-us/microsoft-365/security/office-365-security/detect-and-remediate-illicit-consent-grants

.LINK
    https://learn.microsoft.com/en-us/microsoft-365/compliance/audit-log-activities
#>
Begin {
	#Initializing Hawk Object if not present
    # Check if Hawk object exists and is fully initialized
    # Check if Hawk object exists and is fully initialized
    if (Test-HawkGlobalObject) {
        Initialize-HawkGlobalObject
    }


	Out-LogFile "Gathering Tenant information" -Action
	Test-EXOConnection
}#End BEGIN

PROCESS{
# Make sure our variables are null
$AzureApplicationActivityEvents = $null

Out-LogFile "Searching UAL for Entra ID Application Activities" -Action

# Search the unified audit log for events related to application activity
# https://docs.microsoft.com/en-us/microsoft-365/security/office-365-security/detect-and-remediate-illicit-consent-grants
$AzureApplicationActivityEvents = Get-AllUnifiedAuditLogEntry -UnifiedSearch ("Search-UnifiedAuditLog -RecordType 'AzureActiveDirectory' -Operations 'Add OAuth2PermissionGrant.','Consent to application.' ")

# If null we found no changes to nothing to do here
if ($null -eq $AzureApplicationActivityEvents){
	Out-LogFile "Get-HawkTenantEntraIDAppAuditLog completed successfully" -Information
	Out-LogFile "No Application related events found in the search time frame." -Action
}

# If not null then we must have found some events so flag them
else {
	Out-LogFile "Application Rights Activity found." -Notice
	Out-LogFile "Please review these Entra_ID_Application_Audit.csv to ensure any changes are legitimate." -Notice

	# Go thru each even and prepare it to output to CSV
	Foreach ($event in $AzureApplicationActivityEvents){

		$event.auditdata | ConvertFrom-Json | Select-Object -Property Id,
			Operation,
			ResultStatus,
			Workload,
			ClientIP,
			UserID,
			@{Name='ActorUPN';Expression={($_.ExtendedProperties | Where-Object {$_.Name -eq 'actorUPN'}).value}},
			@{Name='targetName';Expression={($_.ExtendedProperties | Where-Object {$_.Name -eq 'targetName'}).value}},
			@{Name='env_time';Expression={($_.ExtendedProperties | Where-Object {$_.Name -eq 'env_time'}).value}},
			@{Name='correlationId';Expression={($_.ExtendedProperties | Where-Object {$_.Name -eq 'correlationId'}).value}}`
			| Out-MultipleFileType -fileprefix "Entra_ID_Application_Audit" -csv -json -append
	}
}
}#End PROCESS
END{
Out-LogFile "Completed gathering Tenant App Audit Logs" -Information
}#End END
}
