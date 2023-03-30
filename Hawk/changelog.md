# Changelog

## 2.0.0 (2021-01-05)
- Initial Transmigrated Release with new owner
## 2.0.1 (2021-02-07)
- Incorporated workflow and pester tests
- Readme file updated with https://cloudforensicator.com link
- Updated Azure AD SKU options that identity "Premium Licensing"
- Issue #25 - Unified Audit Log AuditData JSON parsing added to "Exchange_UAL_Audit.csv"

## 2.0.2 (2021-05-05)
- Fixed Hidden Mailbox Rule EWS Credential
- Updated Robust Cloud Command version to 2.0.1
- Updated Get-HawkTenantInboxRules.ps1 to new switch in update Robust Cloud Command
- Deprecate "Get-HawkTenantAzureAuthenticationLogs" from Hawk. Azure AD Graph was deprecated and no longer supported. Currently
seeking alternate solution to retrieve Azure AD Sign-in logs.
- Removed dependency of Cloud Connect
- Added dependency of Exchange Online Management V2 PowerShell module and updated functions to reflect

## 2.0.3.1 (2021-05-05)
- Fixed MSOnline Requirement to manifest

## 3.0.0 (2022-04-09)
- Updated community pull requests
a. Encoding to UTF8 - Enhancement - TakayukiTomatsuri
b. Updated $RangeEnd to datetime - Bug - cfc-zcarter
c. Updated Sweep variable - Bug
d. Added Default Tenant Name to Hawk folder name - Issue#86 - Enhancement - Snickasaurus
e. Updated Get-HawkTenantEXOAdmins to accurately list admins that is a group

## 3.1.0 (2023-03-30)
a. Updated community pull requests fixing typo
b. Updated Get-HawkTenantAuditLog.ps1 to Get-HawkTenantAppAuditLog.ps1
c. Added "Get-HawkTenantDomainActivity" function - This function will pull domain config changes from the UAL
d. Added "Get-HawkTenantEDiscoveryLogs" function - This function will pull EDiscovery logs from the UAL
e. Added Export of JSON to "Out-Multifileype" function. This will export returned results to JSON file for further ingestion into a SIEM or other data analysis platform
f. Remove MSOnline requirements
g. Added MS Graph requirements to replace MSOnline
h. Fixed path for System.Net.IPNetwork.dll