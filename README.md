# Hawk Documentation and Resources

Visit [hawkforensics.io](https://hawkforensics.io/) for comprehensive documentation including:

- Detailed installation and permissions guides
- Step-by-step tutorials and "How to" videos
- Troubleshooting help
- Best practices and usage examples

# What is Hawk?

Hawk is a free, open-source PowerShell module that streamlines the collection of forensic data from Microsoft cloud environments. Designed primarily for security professionals, incident responders, and administrators, Hawk automates the gathering of critical log data across Microsoft services, with a focus on Microsoft 365 (M365) and Microsoft Entra ID.

## Core Capabilities

- **Data Collection**: Efficiently gather forensic data with automated collection processes
- **Security Analysis**: Examine security configurations, audit logs, and user activities
- **Export & Report**: Generate both CSV reports and JSON data for SIEM integration

## What Hawk is and isn't

While Hawk includes basic analysis capabilities to flag potential items of interest (such as suspicious mail forwarding rules, over-privileged applications, or risky user activities), it is fundamentally a data collection tool rather than an automated threat detection system.

Hawk streamlines data collection compared to manually running individual queries through web interfaces, freeing up those resources for other administrative tasks. The tool's goal is to quickly get you the data needed to come to a conclusion; not to make the conclusion for you.

# Getting Started

## System Requirements

- Windows operating system with administrator access
- PowerShell 5.0 or above (PowerShell Core will be supported in future)
- Network connectivity to:
  - PowerShell Gallery
  - Graph API
  - Microsoft 365 services

## Installation

```powershell
Install-Module -Name Hawk
```

# Investigation Types

Hawk offers two main investigation approaches:

## Tenant Investigations

- Examines broader Microsoft Cloud tenant settings, audit logs, and security configurations
- Provides an excellent starting point for identifying suspicious patterns
- Use `Start-HawkTenantInvestigation` to begin a tenant-wide investigation

## User Investigations

- Performs deep-dive analysis into individual user accounts
- Examines mailbox configurations, inbox rules, and login histories
- Use `Start-HawkUserInvestigation -UserPrincipleName <user@domain.com>` to investigate specific users

# Understanding Output

Hawk organizes investigation results into a structured directory hierarchy:

```
📂 [Investigation Root]
├── 📂 Tenant/
│   ├── AdminAuditLogConfig.csv
│   ├── OrgConfig.csv
│   ├── _Investigate_*.csv
│   └── [other tenant files]
├── 📂 [user1@domain.com]/
│   ├── Mailbox_Info.csv
│   ├── InboxRules.csv
│   ├── _Investigate_*.csv
│   └── [other user files]
└── 📂 [user2@domain.com]/
    └── [similar structure]
```

Files prefixed with `_Investigate_` contain potentially suspicious findings that warrant further review.

# Contributing

Everyone is welcome to contribute to Hawk. The goal is to maintain a community-led tool that provides security professionals with the resources they need.

## Ways to Contribute

1. **Join the Development Team**: Contact us at hawkpsmodule@gmail.com
2. **Submit Feature Requests**: Use our [feature request template](https://github.com/T0pCyber/hawk/issues/new?template=01_feature_request_form.yml)
3. **Report Issues**: Use our [bug report template](https://github.com/T0pCyber/hawk/issues/new?template=02_bug_report_form.yml)

For critical issues or inquiries, email hawkpsmodule@gmail.com.

# Support

- [PowerShell Gallery Package](https://www.powershellgallery.com/packages/HAWK)
- [GitHub Issues](https://github.com/T0pCyber/hawk/issues)
- [GitHub Discussions](https://github.com/T0pCyber/hawk/discussions)
- Email: hawkpsmodule@gmail.com

# Disclaimer

Hawk is NOT an official MICROSOFT tool. Use of the tool is covered exclusively by the license associated with this GitHub repository.
