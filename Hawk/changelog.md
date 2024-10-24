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
- Encoding to UTF8 - Enhancement - TakayukiTomatsuri
- Updated $RangeEnd to datetime - Bug - cfc-zcarter
- Updated Sweep variable - Bug
- Added Default Tenant Name to Hawk folder name - Issue#86 - Enhancement - Snickasaurus
- Updated Get-HawkTenantEXOAdmins to accurately list admins that is a group

## 3.1.0 (2023-03-30)
- Updated community pull requests fixing typo
- Updated Get-HawkTenantAuditLog.ps1 to Get-HawkTenantAppAuditLog.ps1
- Added "Get-HawkTenantDomainActivity" function - This function will pull domain config changes from the UAL
- Added "Get-HawkTenantEDiscoveryLogs" function - This function will pull EDiscovery logs from the UAL
- Added Export of JSON to "Out-Multifileype" function. This will export returned results to JSON file for further ingestion into a SIEM or other data analysis platform
- Remove MSOnline requirements
- Added MS Graph requirements to replace MSOnline
- Fixed path for System.Net.IPNetwork.dll

## 3.1.1 (2024-10-24)

- Removed Cloud Connect references
- Removed Zipcode from Get-HawkUserAuthHistory.ps1 - IPStack doesn't retrieve Zipcode
- Removed Continent Code from Get-IPGeoLocation
- Removed Test-MSOnlineConnection.ps1 - MSOnline requirements have been removed from Hawk
- Added logging filepath checking the Start-HawkUserInvestigation.ps1
- Updated Get-HawkTenantAZAdmins.ps1. Removed AzureAD module. Added MS Graph cmdlets.
- Updated contact email