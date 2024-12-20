@{
	# Script module or binary module file associated with this manifest
	RootModule         = 'Hawk.psm1'

	# Version number of this module.
	ModuleVersion      = '3.2.3'

	# ID used to uniquely identify this module
	GUID               = '1f6b6b91-79c4-4edf-83a1-66d2dc8c3d85'

	# Author of this module
	Author             = 'Paul Navarro'

	# Company or vendor of this module
	CompanyName        = 'Cloud Forensicator'

	# Copyright statement for this module
	Copyright          = 'Copyright (c) 2023 Paul Navarro'

	# Description of the functionality provided by this module
	Description        = 'Microsoft 365 Incident Response and Threat Hunting PowerShell tool.
	The Hawk is designed to ease the burden on M365 administrators who are performing Cloud forensic tasks for their organization.
	It accelerates the gathering of data from multiple sources in the service that be used to quickly identify malicious presence and activity.'

	# Minimum version of the Windows PowerShell engine required by this module
	PowerShellVersion  = '5.0'

	# Modules that must be imported into the global environment prior to importing
	# this module
	RequiredModules    = @(
		@{ModuleName = 'PSFramework'; ModuleVersion = '1.12.346' },
		@{ModuleName = 'PSAppInsights'; ModuleVersion = '0.9.6' },
		@{ModuleName = 'ExchangeOnlineManagement'; ModuleVersion = '3.0.0' },
		@{ModuleName = 'Microsoft.Graph.Authentication'; ModuleVersion = '2.25.0' },
		@{ModuleName = 'Microsoft.Graph.Identity.DirectoryManagement'; ModuleVersion = '2.25.0' }
	)

	# Assemblies that must be loaded prior to importing this module
	RequiredAssemblies = @('bin\System.Net.IPNetwork.dll')

	# Type files (.ps1xml) to be loaded when importing this module
	# TypesToProcess = @('xml\Hawk.Types.ps1xml')

	# Format files (.ps1xml) to be loaded when importing this module
	# FormatsToProcess = @('xml\Hawk.Format.ps1xml')

	# Functions to export from this module
	FunctionsToExport  =
	'Get-HawkTenantConfiguration',
	'Get-HawkTenantEDiscoveryConfiguration',
	'Get-HawkTenantInboxRules',
	'Get-HawkTenantConsentGrant',
	'Get-HawkTenantRBACChange',
	'Get-HawkTenantAzureAppAuditLog',
	'Get-HawkUserAuthHistory',
	'Get-HawkUserConfiguration',
	'Get-HawkUserEmailForwarding',
	'Get-HawkUserInboxRule',
	'Get-HawkUserMailboxAuditing',
	'Search-HawkTenantActivityByIP',
	'Get-HawkTenantAdminInboxRuleCreation',
	'Get-HawkTenantAdminInboxRuleModification',
	'Get-HawkTenantAdminInboxRuleRemoval',
	'Get-HawkTenantAdminMailboxPermissionChange',
	'Get-HawkTenantImpersonationAccess',
	'Search-HawkTenantEXOAuditLog',
	'Show-HawkHelp',
	'Start-HawkTenantInvestigation',
	'Start-HawkUserInvestigation',
	'Update-HawkModule',
	'Get-HawkUserAdminAudit',
	'Get-HawkTenantAuditLog',
	'Get-HawkTenantAuthHistory',
	'Get-HawkUserHiddenRule',
	'Get-HawkMessageHeader',
	'Get-HawkUserPWNCheck',
	'Get-HawkUserAutoReply',
	'Get-HawkUserMessageTrace',
	'Get-HawkUserMobileDevice',
	'Get-HawkTenantEntraIDAdmin',
	'Get-HawkTenantEXOAdmins',
	'Get-HawkTenantMailItemsAccessed',
	'Get-HawkTenantAppAndSPNCredentialDetail',
	'Get-HawkTenantEntraIDUser',
	'Get-HawkTenantDomainActivity',
	'Get-HawkTenantEDiscoveryLog'

	# Cmdlets to export from this module
	# CmdletsToExport = ''

	# Variables to export from this module
	# VariablesToExport = ''

	# Aliases to export from this module
	# AliasesToExport = ''

	# List of all modules packaged with this module
	ModuleList         = @()

	# List of all files packaged with this module
	FileList           = @()

	# Private data to pass to the module specified in ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
	PrivateData        = @{

		#Support for PowerShellGet galleries.
		PSData = @{

			# Tags applied to this module. These help with module discovery in online galleries.
			Tags         = @("O365", "Security", "Audit", "Breach", "Investigation", "Exchange", "EXO", "Compliance", "Logon", "M365", "Incident-Response", "Solarigate")

			# A URL to the license for this module.
			LicenseUri   = 'https://github.com/T0pCyber/Hawk/LICENSE'

			# A URL to the main website for this project.
			ProjectUri   = 'https://github.com/T0pCyber/Hawk'

			# A URL to an icon representing this module.
			IconUri      = 'https://i.ibb.co/XXH4500/Hawk.png'

			# ReleaseNotes of this module
			ReleaseNotes = 'https://github.com/T0pCyber/Hawk/Hawk/changelog.md'

		} # End of PSData hashtable

	} # End of PrivateData hashtable
}