Function Get-HawkAllGraphResult {
    <#
    .SYNOPSIS
        Internal helper that runs a Microsoft Graph GET request and returns all paged results.

    .DESCRIPTION
        Wraps Invoke-MgGraphRequest to execute a Microsoft Graph GET request against the currently
        connected session (established by Test-GraphConnection / Connect-MgGraph) and transparently
        follows @odata.nextLink paging until every result has been retrieved.

        The request is sent with the "Prefer: include-unknown-enum-members" header so that evolvable
        enumeration values introduced for newer features (for example the agent identity types
        returned by Microsoft Entra Agent ID) are returned rather than collapsed to
        unknownFutureValue.

        This helper targets newer or preview Graph surfaces - such as the agentIdentity service
        principal cast and the /beta agent log endpoints - where the typed Microsoft.Graph cmdlets
        do not yet expose the required casts or properties. If the request fails (for example
        because the endpoint is not available in the tenant, or the required permission has not been
        consented), the function logs the error and returns $null so callers can degrade gracefully
        instead of terminating the investigation.

    .PARAMETER Uri
        The full Microsoft Graph request URI to retrieve, including the API version segment, for
        example "https://graph.microsoft.com/v1.0/servicePrincipals/microsoft.graph.agentIdentity".

    .PARAMETER Headers
        Optional additional request headers to merge with the defaults. Any key supplied here
        overrides the matching default header.

    .OUTPUTS
        System.Object[]. The aggregated collection of result objects (the combined "value" arrays
        across all pages), or $null if the request failed.

    .EXAMPLE
        Get-HawkAllGraphResult -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/microsoft.graph.agentIdentity"

        Returns every agent identity service principal in the tenant, following paging automatically.

    .NOTES
        Internal helper. Requires an active Microsoft Graph connection (Test-GraphConnection).
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter(Mandatory = $false)]
        [hashtable]$Headers
    )

    # Default headers. include-unknown-enum-members ensures evolvable enum values (such as the
    # agent identity types) are returned instead of unknownFutureValue.
    $requestHeaders = @{ 'Prefer' = 'include-unknown-enum-members' }
    if ($Headers) {
        foreach ($key in $Headers.Keys) {
            $requestHeaders[$key] = $Headers[$key]
        }
    }

    $results = New-Object System.Collections.ArrayList
    $nextUri = $Uri

    try {
        while (-not [string]::IsNullOrEmpty($nextUri)) {
            $response = Invoke-MgGraphRequest -Method GET -Uri $nextUri -Headers $requestHeaders -OutputType PSObject -ErrorAction Stop

            # Collection responses expose their items under the "value" property; single-object
            # responses are returned directly.
            if ($null -ne $response.value) {
                foreach ($item in $response.value) {
                    [void]$results.Add($item)
                }
            }
            elseif ($null -ne $response -and (-not ($response.PSObject.Properties.Name -contains 'value'))) {
                [void]$results.Add($response)
            }

            $nextUri = $response.'@odata.nextLink'
        }
    }
    catch {
        Out-LogFile "Microsoft Graph request failed for '$Uri': $($_.Exception.Message)" -isError
        return $null
    }

    return $results.ToArray()
}
