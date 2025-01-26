function Write-HawkInvestigationSummary {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [DateTime]$StartTime,

        [Parameter(Mandatory = $true)]
        [DateTime]$EndTime,

        [Parameter(Mandatory = $true)]
        [ValidateSet('User', 'Tenant')]
        [string]$InvestigationType,

        [Parameter()]
        [array]$UserPrincipalName
    )

    # Calculate total duration
    $duration = $EndTime - $StartTime
    
    # Create a more readable duration string with labels
    $durationParts = @()
    if ($duration.Hours -gt 0) {
        $durationParts += "{0} hours" -f $duration.Hours
    }
    if ($duration.Minutes -gt 0) {
        $durationParts += "{0} minutes" -f $duration.Minutes
    }
    if ($duration.Seconds -gt 0 -or $durationParts.Count -eq 0) {
        $durationParts += "{0} seconds" -f $duration.Seconds
    }
    $durationStr = $durationParts -join ", "

    Write-Output ""
    Out-LogFile "=========================================================================" -Information
    
    # Output different message based on investigation type
    if ($InvestigationType -eq 'Tenant') {
        Out-LogFile "Tenant Investigation complete for tenant: $($Hawk.TenantName)" -Information
    } else {
        # Handle user investigation output
        if ($UserPrincipalName.Count -eq 1) {
            # Single user case
            if ($UserPrincipalName[0] -is [PSCustomObject]) {
                $upn = $UserPrincipalName[0].UserPrincipalName
            } else {
                $upn = $UserPrincipalName[0]
            }
            Out-LogFile "User Investigation complete for user: '$upn'" -Information
        } else {
            # Multiple users case
            Out-LogFile "User Investigation complete for users:" -Information
            foreach ($user in $UserPrincipalName) {
                if ($user -is [PSCustomObject]) {
                    $upn = $user.UserPrincipalName
                } else {
                    $upn = $user
                }
                Out-LogFile "* $upn" -Information
            }
        }
    }
    
    Out-LogFile "Total run time: $durationStr" -Information
    Out-LogFile "Please review investigation files at: $($Hawk.FilePath)" -Information
    
    # Only show the additional investigation message for tenant investigations
    if ($InvestigationType -eq 'Tenant') {
        Out-LogFile "To investigate specific users, run: Start-HawkUserInvestigation" -Information
    }
    
    Out-LogFile "=========================================================================" -Information
    Write-Output ""
}