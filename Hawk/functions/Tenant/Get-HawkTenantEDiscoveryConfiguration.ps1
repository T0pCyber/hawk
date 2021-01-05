# Find any roles that have access to key edisocovery cmdlets and output the folks who have those rights
Function Get-HawkTenantEDiscoveryConfiguration {

    Test-EXOConnection
    Send-AIEvent -Event "CmdRun"

    Out-LogFile "Gathering Tenant information about E-Discovery Configuration" -action
	
    # Nulling our our role arrays
    [array]$Roles = $null
    [array]$RoleAssignements = $null
	
    # Look for E-Discovery Roles and who they might be assigned to
    $EDiscoveryCmdlets = "New-MailboxSearch", "Search-Mailbox"
	
    # Find any roles that have these critical ediscovery cmdlets in them
    # Bad actors with sufficient rights could have created new roles so we search for them
    Foreach ($cmdlet in $EDiscoveryCmdlets) {
        [array]$Roles = $Roles + (Get-ManagementRoleEntry ("*\" + $cmdlet))
    }
	
    # Select just the unique entries based on role name
    $UniqueRoles = Select-UniqueObject -ObjectArray $Roles -Property Role
	
    Out-LogFile ("Found " + $UniqueRoles.count + " Roles with E-Discovery Rights")
    $UniqueRoles | Out-MultipleFileType -FilePrefix "EDiscoveryRoles" -csv -xml
	
    # Get everyone who is assigned one of these roles
    Foreach ($Role in $UniqueRoles) {
        [array]$RoleAssignements = $RoleAssignements + (Get-ManagementRoleAssignment -Role $Role.role -Delegating $false)
    }
	
    Out-LogFile ("Found " + $RoleAssignements.count + " Role Assignements for these Roles")
    $RoleAssignements | Out-MultipleFileType -FilePreFix "EDiscoveryRoleAssignments" -csv -xml

    <#
 
	.SYNOPSIS
	Looks for users that have e-discovery rights.

	.DESCRIPTION
	Searches for all roles that have e-discovery cmdlets.
	Searches for all users / groups that have access to those roles.	
		
	.OUTPUTS

	File: EDiscoveryRoles.csv
	Path: \
	Description: All roles that have access to the New-MailboxSearch and Search-Mailbox cmdlets

	File: EDiscoveryRoles.xml
	Path: \XML
	Description: All roles that have access to the New-MailboxSearch and Search-Mailbox cmdlets as CLI XML

	File: EDiscoveryRoleAssignments.csv
	Path: \
	Description: All users that are assigned one of the discovered roles

	File: EDiscoveryRoleAssignments.xml
	Path: \XML
	Description: All users that are assigned one of the discovered roles as CLI XML

	.EXAMPLE
	Get-HawkTenantEDiscoveryConfiguration 

	Runs the cmdlet against the current logged in tenant and outputs ediscovery information
	
	#>
	
}