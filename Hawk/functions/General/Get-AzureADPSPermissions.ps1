Function Get-AzureADPSPermissions {

<#
.SYNOPSIS
    Lists delegated permissions (OAuth2PermissionGrants) and application permissions (AppRoleAssignments).
.PARAMETER DelegatedPermissions
    If set, will return delegated permissions. If neither this switch nor the ApplicationPermissions switch is set,
    both application and delegated permissions will be returned.
.PARAMETER ApplicationPermissions
    If set, will return application permissions. If neither this switch nor the DelegatedPermissions switch is set,
    both application and delegated permissions will be returned.
.PARAMETER UserProperties
    The list of properties of user objects to include in the output. Defaults to DisplayName only.
.PARAMETER ServicePrincipalProperties
    The list of properties of service principals (i.e. apps) to include in the output. Defaults to DisplayName only.
.PARAMETER ShowProgress
    Whether or not to display a progress bar when retrieving application permissions (which could take some time).
.PARAMETER PrecacheSize
    The number of users to pre-load into a cache. For tenants with over a thousand users,
    increasing this may improve performance of the script.
.EXAMPLE
    PS C:\> .\Get-AzureADPSPermissions.ps1 | Export-Csv -Path "permissions.csv" -NoTypeInformation
    Generates a CSV report of all permissions granted to all apps.
.EXAMPLE
    PS C:\> .\Get-AzureADPSPermissions.ps1 -ApplicationPermissions -ShowProgress | Where-Object { $_.Permission -eq "Directory.Read.All" }
    Get all apps which have application permissions for Directory.Read.All.
.EXAMPLE
    PS C:\> .\Get-AzureADPSPermissions.ps1 -UserProperties @("DisplayName", "UserPrincipalName", "Mail") -ServicePrincipalProperties @("DisplayName", "AppId")
    Gets all permissions granted to all apps and includes additional properties for users and service principals.

.LINK
https://gist.github.com/psignoret/9d73b00b377002456b24fcb808265c23

#>

[CmdletBinding()]
param(
    [switch] $DelegatedPermissions,

    [switch] $ApplicationPermissions,

    [string[]] $UserProperties = @("DisplayName"),

    [string[]] $ServicePrincipalProperties = @("DisplayName"),

    [switch] $ShowProgress,

    [int] $PrecacheSize = 999
)

# Get tenant details to test that Connect-AzureAD has been called
try {
    $tenant_details = Get-AzureADTenantDetail
} catch {
    throw "You must call Connect-AzureAD before running this script."
}
Write-Verbose ("TenantId: {0}, InitialDomain: {1}" -f `
                $tenant_details.ObjectId, `
                ($tenant_details.VerifiedDomains | Where-Object { $_.Initial }).Name)

# An in-memory cache of objects by {object ID} andy by {object class, object ID}
$script:ObjectByObjectId = @{}
$script:ObjectByObjectClassId = @{}

# Function to add an object to the cache
function CacheObject ($Object) {
    if ($Object) {
        if (-not $script:ObjectByObjectClassId.ContainsKey($Object.ObjectType)) {
            $script:ObjectByObjectClassId[$Object.ObjectType] = @{}
        }
        $script:ObjectByObjectClassId[$Object.ObjectType][$Object.ObjectId] = $Object
        $script:ObjectByObjectId[$Object.ObjectId] = $Object
    }
}

# Function to retrieve an object from the cache (if it's there), or from Azure AD (if not).
function GetObjectByObjectId ($ObjectId) {
    if (-not $script:ObjectByObjectId.ContainsKey($ObjectId)) {
        Write-Verbose ("Querying Azure AD for object '{0}'" -f $ObjectId)
        try {
            $object = Get-AzureADObjectByObjectId -ObjectId $ObjectId
            CacheObject -Object $object
        } catch {
            Write-Verbose "Object not found."
        }
    }
    return $script:ObjectByObjectId[$ObjectId]
}

# Function to retrieve all OAuth2PermissionGrants, either by directly listing them (-FastMode)
# or by iterating over all ServicePrincipal objects. The latter is required if there are more than
# 999 OAuth2PermissionGrants in the tenant, due to a bug in Azure AD.
function GetOAuth2PermissionGrants ([switch]$FastMode) {
    if ($FastMode) {
        Get-AzureADOAuth2PermissionGrant -All $true
    } else {
        $script:ObjectByObjectClassId['ServicePrincipal'].GetEnumerator() | ForEach-Object { $i = 0 } {
            if ($ShowProgress) {
                Write-Progress -Activity "Retrieving delegated permissions..." `
                               -Status ("Checked {0}/{1} apps" -f $i++, $servicePrincipalCount) `
                               -PercentComplete (($i / $servicePrincipalCount) * 100)
            }

            $client = $_.Value
            Get-AzureADServicePrincipalOAuth2PermissionGrant -ObjectId $client.ObjectId
        }
    }
}

$empty = @{} # Used later to avoid null checks

# Get all ServicePrincipal objects and add to the cache
Write-Verbose "Retrieving all ServicePrincipal objects..."
Get-AzureADServicePrincipal -All $true | ForEach-Object {
    CacheObject -Object $_
}
$servicePrincipalCount = $script:ObjectByObjectClassId['ServicePrincipal'].Count

if ($DelegatedPermissions -or (-not ($DelegatedPermissions -or $ApplicationPermissions))) {

    # Get one page of User objects and add to the cache
    Write-Verbose ("Retrieving up to {0} User objects..." -f $PrecacheSize)
    Get-AzureADUser -Top $PrecacheSize | Where-Object {
        CacheObject -Object $_
    }

    Write-Verbose "Testing for OAuth2PermissionGrants bug before querying..."
    $fastQueryMode = $false
    try {
        # There's a bug in Azure AD Graph which does not allow for directly listing
        # oauth2PermissionGrants if there are more than 999 of them. The following line will
        # trigger this bug (if it still exists) and throw an exception.
        $null = Get-AzureADOAuth2PermissionGrant -Top 999
        $fastQueryMode = $true
    } catch {
        if ($_.Exception.Message -and $_.Exception.Message.StartsWith("Unexpected end when deserializing array.")) {
            Write-Verbose ("Fast query for delegated permissions failed, using slow method...")
        } else {
            throw $_
        }
    }

    # Get all existing OAuth2 permission grants, get the client, resource and scope details
    Write-Verbose "Retrieving OAuth2PermissionGrants..."
    GetOAuth2PermissionGrants -FastMode:$fastQueryMode | ForEach-Object {
        $grant = $_
        if ($grant.Scope) {
            $grant.Scope.Split(" ") | Where-Object { $_ } | ForEach-Object {

                $scope = $_

                $grantDetails =  [ordered]@{
                    "PermissionType" = "Delegated"
                    "ClientObjectId" = $grant.ClientId
                    "ResourceObjectId" = $grant.ResourceId
                    "Permission" = $scope
                    "ConsentType" = $grant.ConsentType
                    "PrincipalObjectId" = $grant.PrincipalId
                }

                # Add properties for client and resource service principals
                if ($ServicePrincipalProperties.Count -gt 0) {

                    $client = GetObjectByObjectId -ObjectId $grant.ClientId
                    $resource = GetObjectByObjectId -ObjectId $grant.ResourceId

                    $insertAtClient = 2
                    $insertAtResource = 3
                    foreach ($propertyName in $ServicePrincipalProperties) {
                        $grantDetails.Insert($insertAtClient++, "Client$propertyName", $client.$propertyName)
                        $insertAtResource++
                        $grantDetails.Insert($insertAtResource, "Resource$propertyName", $resource.$propertyName)
                        $insertAtResource ++
                    }
                }

                # Add properties for principal (will all be null if there's no principal)
                if ($UserProperties.Count -gt 0) {

                    $principal = $empty
                    if ($grant.PrincipalId) {
                        $principal = GetObjectByObjectId -ObjectId $grant.PrincipalId
                    }

                    foreach ($propertyName in $UserProperties) {
                        $grantDetails["Principal$propertyName"] = $principal.$propertyName
                    }
                }

                Return New-Object PSObject -Property $grantDetails
            }
        }
    }
}

if ($ApplicationPermissions -or (-not ($DelegatedPermissions -or $ApplicationPermissions))) {

    # Iterate over all ServicePrincipal objects and get app permissions
    Write-Verbose "Retrieving AppRoleAssignments..."
    $script:ObjectByObjectClassId['ServicePrincipal'].GetEnumerator() | ForEach-Object { $i = 0 } {

        if ($ShowProgress) {
            Write-Progress -Activity "Retrieving application permissions..." `
                        -Status ("Checked {0}/{1} apps" -f $i++, $servicePrincipalCount) `
                        -PercentComplete (($i / $servicePrincipalCount) * 100)

            if ($i -eq $servicePrincipalCount){
                Write-Progress -Completed -Activity "Retrieving application permissions..." `
            }
        }

        $sp = $_.Value

        Get-AzureADServiceAppRoleAssignedTo -ObjectId $sp.ObjectId -All $true `
        | Where-Object { $_.PrincipalType -eq "ServicePrincipal" } | ForEach-Object {
            $assignment = $_

            $resource = GetObjectByObjectId -ObjectId $assignment.ResourceId
            $appRole = $resource.AppRoles | Where-Object { $_.Id -eq $assignment.Id }

            $grantDetails = [ordered]@{
                "PermissionType" = "Application"
                "ClientObjectId" = $assignment.PrincipalId
                "ResourceObjectId" = $assignment.ResourceId
                "Permission" = $appRole.Value
            }

            # Add properties for client and resource service principals
            if ($ServicePrincipalProperties.Count -gt 0) {

                $client = GetObjectByObjectId -ObjectId $assignment.PrincipalId

                $insertAtClient = 2
                $insertAtResource = 3
                foreach ($propertyName in $ServicePrincipalProperties) {
                    $grantDetails.Insert($insertAtClient++, "Client$propertyName", $client.$propertyName)
                    $insertAtResource++
                    $grantDetails.Insert($insertAtResource, "Resource$propertyName", $resource.$propertyName)
                    $insertAtResource ++
                }
            }

            Return New-Object PSObject -Property $grantDetails
        }
    }
}
}