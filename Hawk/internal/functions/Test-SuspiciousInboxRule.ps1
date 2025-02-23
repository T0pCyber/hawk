Function Test-SuspiciousInboxRule {
    <#
    .SYNOPSIS
        Internal helper function to detect suspicious inbox rule patterns.
    
    .DESCRIPTION
        Analyzes inbox rule properties to identify potentially suspicious configurations
        like external forwarding, message deletion, or targeting of security-related content.
        Used by both rule creation and modification audit functions.
    
    .PARAMETER Rule
        The parsed inbox rule object to analyze.
    
    .PARAMETER Reasons
        [ref] array to store the reasons why a rule was flagged as suspicious.
    
    .OUTPUTS
        Boolean indicating if the rule matches suspicious patterns.
        Populates the Reasons array parameter with explanations if suspicious.
    
    .EXAMPLE
        $reasons = @()
        $isSuspicious = Test-SuspiciousInboxRule -Rule $ruleObject -Reasons ([ref]$reasons)
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [object]$Rule,

        [Parameter(Mandatory = $true)]
        [ref]$Reasons
    )

    $isSuspicious = $false
    $suspiciousReasons = @()

    # Check forwarding/redirection configurations
    if ($Rule.Param_ForwardTo) { 
        $isSuspicious = $true
        $suspiciousReasons += "forwards to: $($Rule.Param_ForwardTo)" 
    }
    if ($Rule.Param_ForwardAsAttachmentTo) { 
        $isSuspicious = $true
        $suspiciousReasons += "forwards as attachment to: $($Rule.Param_ForwardAsAttachmentTo)" 
    }
    if ($Rule.Param_RedirectTo) { 
        $isSuspicious = $true
        $suspiciousReasons += "redirects to: $($Rule.Param_RedirectTo)" 
    }

    # Check deletion/move to deleted items
    if ($Rule.Param_DeleteMessage) { 
        $isSuspicious = $true
        $suspiciousReasons += "deletes messages" 
    }
    if ($Rule.Param_MoveToFolder -eq 'Deleted Items') { 
        $isSuspicious = $true
        $suspiciousReasons += "moves to Deleted Items" 
    }

    # Update the reasons array with our findings
    $Reasons.Value = $suspiciousReasons

    return $isSuspicious
}