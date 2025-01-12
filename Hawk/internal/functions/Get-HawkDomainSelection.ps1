function Get-HawkDomainSelection {
    <#
    .SYNOPSIS
        Gets a list of domains from Microsoft Graph and prompts user to select one.
    
    .DESCRIPTION
        This function retrieves all verified domains from Microsoft Graph API,
        displays them in a numbered list with the default domain marked,
        and prompts the user to select one. It validates input and handles
        error cases according to the specified use case.
    
    .OUTPUTS
        String containing the selected domain name
    
    .EXAMPLE
        Get-HawkDomainSelection
        Returns the domain selected by the user
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()
    
    try {
        # Get domains from Microsoft Graph
        $domains = Get-MgDomain -ErrorAction Stop | Where-Object { $_.IsVerified -eq $true }
        
        if ($null -eq $domains -or $domains.Count -eq 0) {
            Out-LogFile "Unable to retrieve domain list from Microsoft Graph." -isError
            throw "No verified domains found in tenant."
        }

        # Find default domain
        $defaultDomain = $domains | Where-Object { $_.IsDefault -eq $true }
        if (-not $defaultDomain) {
            $defaultDomain = $domains[0]  # Fallback to first domain if no default found
        }

        # Display domain list
        Write-Output "`nDomain Selection:"
        for ($i = 0; $i -lt $domains.Count; $i++) {
            $domain = $domains[$i]
            $isDefault = if ($domain.Id -eq $defaultDomain.Id) { " (Default)" } else { "" }
            Write-Output ("{0}) {1}{2}" -f ($i + 1), $domain.Id, $isDefault)
        }

        # Get user selection
        do {
            Out-LogFile "Please select a domain to investigate (1-$($domains.Count), or Enter for default): " -isPrompt -NoNewLine
            $selection = Read-Host
            
            # Default selection if user just hits enter
            if ([string]::IsNullOrEmpty($selection)) {
                return $defaultDomain.Id
            }

            # Validate numeric input
            if ($selection -match '^\d+$') {
                $index = [int]$selection - 1
                if ($index -ge 0 -and $index -lt $domains.Count) {
                    return $domains[$index].Id
                }
            }

            Out-LogFile "Invalid selection. Please enter a number between 1 and $($domains.Count)" -isWarning
        } while ($true)
    }
    catch {
        Out-LogFile $_.Exception.Message -isError
        throw "Failed to get domain selection: $($_.Exception.Message)"
    }
}