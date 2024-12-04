Function Get-AzureADPSPermission {
<#
.SYNOPSIS
    Lists delegated permissions (OAuth2PermissionGrants) and application permissions (AppRoleAssignments).

.DESCRIPTION
    Lists delegated permissions (OAuth2PermissionGrants) and application permissions (AppRoleAssignments)
    using Microsoft Graph API. This function retrieves and formats permission information for analysis
    of application and delegated permissions in your tenant.

.PARAMETER DelegatedPermissions
    If set, will return delegated permissions. If neither this switch nor the ApplicationPermissions
    switch is set, both application and delegated permissions will be returned.

.PARAMETER ApplicationPermissions
    If set, will return application permissions. If neither this switch nor the DelegatedPermissions
    switch is set, both application and delegated permissions will be returned.

.PARAMETER UserProperties
    The list of properties of user objects to include in the output. Defaults to DisplayName only.

.PARAMETER ServicePrincipalProperties
    The list of properties of service principals (i.e. apps) to include in the output.
    Defaults to DisplayName only.

.PARAMETER ShowProgress
    Whether or not to display a progress bar when retrieving application permissions (which could take some time).

.PARAMETER PrecacheSize
    The number of users to pre-load into a cache. For tenants with over a thousand users,
    increasing this may improve performance of the script.

.EXAMPLE
    PS C:\> Get-AzureADPSPermission | Export-Csv -Path "permissions.csv" -NoTypeInformation
    Generates a CSV report of all permissions granted to all apps.

.EXAMPLE
    PS C:\> Get-AzureADPSPermission -ApplicationPermissions -ShowProgress | Where-Object { $_.Permission -eq "Directory.Read.All" }
    Get all apps which have application permissions for Directory.Read.All.

.EXAMPLE
    PS C:\> Get-AzureADPSPermission -UserProperties @("DisplayName", "UserPrincipalName", "Mail") -ServicePrincipalProperties @("DisplayName", "AppId")
    Gets all permissions granted to all apps and includes additional properties for users and service principals.

.NOTES
    This function requires Microsoft.Graph PowerShell module and appropriate permissions:
    - Application.Read.All
    - Directory.Read.All
#>
    [CmdletBinding()]
    param(
        [switch] $DelegatedPermissions,
        [switch] $ApplicationPermissions,
        [string[]] $UserProperties = @("DisplayName"),
        [string[]] $ServicePrincipalProperties = @("DisplayName"),
        [switch] $ShowProgress,
        [System.Int32] $PrecacheSize = 999
    )

    # Verify Graph connection
    try {
        $tenant_details = Get-MgOrganization
    }
    catch {
        throw "You must call Connect-MgGraph before running this script."
    }
    Write-Verbose ("TenantId: {0}" -f $tenant_details.Id)

    # Cache objects
    $script:ObjectByObjectId = @{}
    $script:ObjectByObjectType = @{
        'ServicePrincipal' = @{}
        'User' = @{}
    }

    function CacheObject ($Object, $Type) {
        if ($Object) {
            $script:ObjectByObjectType[$Type][$Object.Id] = $Object
            $script:ObjectByObjectId[$Object.Id] = $Object
        }
    }

    function GetObjectByObjectId ($ObjectId) {
        if (-not $script:ObjectByObjectId.ContainsKey($ObjectId)) {
            Write-Verbose ("Querying Graph API for object '{0}'" -f $ObjectId)
            try {
                $object = Get-MgDirectoryObject -DirectoryObjectId $ObjectId
                # Determine type from OdataType
                $type = $object.AdditionalProperties.'@odata.type'.Split('.')[-1]
                CacheObject -Object $object -Type $type
            }
            catch {
                Write-Verbose "Object not found."
            }
        }
        return $script:ObjectByObjectId[$ObjectId]
    }

    # Cache all service principals
    Write-Verbose "Retrieving all ServicePrincipal objects..."
    $servicePrincipals = Get-MgServicePrincipal -All
    foreach($sp in $servicePrincipals) {
        CacheObject -Object $sp -Type 'ServicePrincipal'
    }
    $servicePrincipalCount = $servicePrincipals.Count

    # Cache users
    Write-Verbose ("Retrieving up to {0} User objects..." -f $PrecacheSize)
    $users = Get-MgUser -Top $PrecacheSize
    foreach($user in $users) {
        CacheObject -Object $user -Type 'User'
    }

    if ($DelegatedPermissions -or (-not ($DelegatedPermissions -or $ApplicationPermissions))) {
        Write-Verbose "Retrieving OAuth2PermissionGrants..."
        $oauth2Grants = Get-MgOAuth2PermissionGrant -All

        foreach ($grant in $oauth2Grants) {
            if ($grant.Scope) {
                $grant.Scope.Split(" ") | Where-Object { $_ } | ForEach-Object {
                    $scope = $_

                    $grantDetails = [ordered]@{
                        "PermissionType" = "Delegated"
                        "ClientObjectId" = $grant.ClientId
                        "ResourceObjectId" = $grant.ResourceId
                        "Permission" = $scope
                        "ConsentType" = $grant.ConsentType
                        "PrincipalObjectId" = $grant.PrincipalId
                    }

                    # Add service principal properties
                    if ($ServicePrincipalProperties.Count -gt 0) {
                        $client = $script:ObjectByObjectId[$grant.ClientId]
                        $resource = $script:ObjectByObjectId[$grant.ResourceId]

                        $insertAtClient = 2
                        $insertAtResource = 3
                        foreach ($propertyName in $ServicePrincipalProperties) {
                            $grantDetails.Insert($insertAtClient++, "Client$propertyName", $client.$propertyName)
                            $insertAtResource++
                            $grantDetails.Insert($insertAtResource, "Resource$propertyName", $resource.$propertyName)
                            $insertAtResource++
                        }
                    }

                    # Add user properties
                    if ($UserProperties.Count -gt 0) {
                        $principal = if ($grant.PrincipalId) {
                            $script:ObjectByObjectId[$grant.PrincipalId]
                        } else { @{} }

                        foreach ($propertyName in $UserProperties) {
                            $grantDetails["Principal$propertyName"] = $principal.$propertyName
                        }
                    }

                    New-Object PSObject -Property $grantDetails
                }
            }
        }
    }

    if ($ApplicationPermissions -or (-not ($DelegatedPermissions -or $ApplicationPermissions))) {
        Write-Verbose "Retrieving AppRoleAssignments..."

        $i = 0
        foreach ($sp in $servicePrincipals) {
            if ($ShowProgress) {
                Write-Progress -Activity "Retrieving application permissions..." `
                            -Status ("Checked {0}/{1} apps" -f $i++, $servicePrincipalCount) `
                            -PercentComplete (($i / $servicePrincipalCount) * 100)
            }

            $appRoleAssignments = Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $sp.Id -All

            foreach ($assignment in $appRoleAssignments) {
                if ($assignment.PrincipalType -eq "ServicePrincipal") {
                    $resource = $script:ObjectByObjectId[$assignment.ResourceId]
                    $appRole = $resource.AppRoles | Where-Object { $_.Id -eq $assignment.AppRoleId }

                    $grantDetails = [ordered]@{
                        "PermissionType" = "Application"
                        "ClientObjectId" = $assignment.PrincipalId
                        "ResourceObjectId" = $assignment.ResourceId
                        "Permission" = $appRole.Value
                    }

                    if ($ServicePrincipalProperties.Count -gt 0) {
                        $client = $script:ObjectByObjectId[$assignment.PrincipalId]

                        $insertAtClient = 2
                        $insertAtResource = 3
                        foreach ($propertyName in $ServicePrincipalProperties) {
                            $grantDetails.Insert($insertAtClient++, "Client$propertyName", $client.$propertyName)
                            $insertAtResource++
                            $grantDetails.Insert($insertAtResource, "Resource$propertyName", $resource.$propertyName)
                            $insertAtResource++
                        }
                    }

                    New-Object PSObject -Property $grantDetails
                }
            }
        }

        if ($ShowProgress) {
            Write-Progress -Completed -Activity "Retrieving application permissions..."
        }
    }
}