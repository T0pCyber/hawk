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

## 3.0.0 (2022-01-21)
- Updated community pull requests
a. Encoding to UTF8 - TakayukiTomatsuri
b. Updated $RangeEnd to datetime - cfc-zcarter
c. Updated Sweep variable - Bug
d. 
