Function Get-HawkUserHiddenRule {
    <#
    .SYNOPSIS
    Pulls inbox rules for the specified user using EWS.
    .DESCRIPTION
    Pulls inbox rules for the specified user using EWS.
    Searches the resulting rules looking for "hidden" rules.

    Requires impersonation:
    https://docs.microsoft.com/en-us/exchange/client-developer/exchange-web-services/how-to-configure-impersonation

    Since the rules are hidden we have to pull it as a message instead of a rule.
    That means that the only information we can get back is the ID and Priority of the rule.
    Once a mailbox has been identified as having a hidden rule please use MFCMapi to review and remove the rule as needed.

    https://blogs.msdn.microsoft.com/hkong/2015/02/27/how-to-delete-corrupted-hidden-inbox-rules-from-a-mailbox-using-mfcmapi/
    .PARAMETER UserPrincipalName
    Single UPN of a user, comma separated list of UPNs, or array of objects that contain UPNs.
    .PARAMETER EWSCredential
    Credentials of a user that can impersonate the target user/users.
    Gather using (get-credential)
    Does NOT work with MFA protected accounts at this time.
    .OUTPUTS

    File: _Investigate.txt
    Path: \
    Description: Adds any hidden rules found here to be investigated

    File: EWS_Inbox_rule.csv
    Path: \<User>
    Description: Inbox rules that were found with EWS
    .EXAMPLE

    Get-HawkUserHiddenRule -UserPrincipalName user@contoso.com -EWSCredential (get-credential)

    Searches user@contoso.com looking for hidden inbox rules using the provided credentials
    .EXAMPLE

    Get-HawkUserHiddenRule -UserPrincipalName (get-mailbox -Filter {Customattribute1 -eq "C-level"})

    Looks for hidden inbox rules for all users who have "C-Level" set in CustomAttribute1
    #>
    param (
        [Parameter(Mandatory = $true)]
        [array]$UserPrincipalName,
        [System.Management.Automation.PSCredential]$EWSCredential
    )

    Test-EXOConnection
    Send-AIEvent -Event "CmdRun"

    # Verify our UPN input
    [array]$UserArray = Test-UserObject -ToTest $UserPrincipalName

    # Process each object received
    foreach ($Object in $UserArray) {

        # Push the UPN into $user for ease of use
        $user = $Object.UserPrincipalName

        # Determine if the email address is null or empty
        [string]$EmailAddress = (Get-EXOMailbox $user).PrimarySmtpAddress
        if ([string]::IsNullOrEmpty($EmailAddress)) {
            Write-Warning "No SMTP Address found. Skipping."
            return $null
        }

        # If we don't have a credential object, ask for credentials
        if ($null -eq $EWSCredential) {
            Out-LogFile "Please provide credentials that have impersonation rights to the mailbox you are looking to check" -Information
            $EWSCredential = Get-Credential
        }

        # Import the EWS Managed API
        if (Test-Path 'C:\Program Files\Microsoft\Exchange\Web Services\2.2\Microsoft.Exchange.WebServices.dll') {
            Out-LogFile "EWS Managed API Found" -Information
        } else {
            Write-Error "Please install EWS Managed API 2.2 `nhttp://www.microsoft.com/en-us/download/details.aspx?id=42951" -ErrorAction Stop
        }

        # Import the EWS Managed API DLL
        Import-Module 'C:\Program Files\Microsoft\Exchange\Web Services\2.2\Microsoft.Exchange.WebServices.dll'

        # Set up the EWS Connection
        Write-Information ("Setting up connection for " + $EmailAddress)
        $exchService = New-Object Microsoft.Exchange.WebServices.Data.ExchangeService -ArgumentList ([Microsoft.Exchange.WebServices.Data.ExchangeVersion]::Exchange2013_Sp1)
        $exchService.Credentials = New-Object Microsoft.Exchange.WebServices.Data.WebCredentials($EWSCredential.Username, $EWSCredential.GetNetworkCredential().Password)

        # Autodiscover or use global EWS URL
        if ($null -eq $EWSUrl) {
            $exchService.AutodiscoverUrl($EmailAddress, { $true })
            $exchService.Url | Set-Variable -Name EWSUrl -Scope Global
        } else {
            $exchService.Url = $EWSUrl
        }

        # Set impersonation
        $exchService.ImpersonatedUserId = New-Object Microsoft.Exchange.WebServices.Data.ImpersonatedUserId([Microsoft.Exchange.WebServices.Data.ConnectingIdType]::SmtpAddress, $EmailAddress)

        # Add the Anchor mailbox to the HTTP header
        $exchService.HttpHeaders.Add("X-AnchorMailbox", [string]$EmailAddress)

        # Search for hidden rules
        $SearchFilter = New-Object Microsoft.Exchange.WebServices.Data.SearchFilter+IsEqualTo([Microsoft.Exchange.WebServices.Data.ItemSchema]::ItemClass, "IPM.Rule.Version2.Message")
        $ItemView = New-Object Microsoft.Exchange.WebServices.Data.ItemView(500)
        $ItemView.Traversal = [Microsoft.Exchange.WebServices.Data.ItemTraversal]::Associated

        # Create our property set to view
        $PR_RULE_MSG_NAME = New-Object Microsoft.Exchange.WebServices.Data.ExtendedPropertyDefinition(0x65EC, [Microsoft.Exchange.WebServices.Data.MapiPropertyType]::String)
        $PR_RULE_MSG_PROVIDER = New-Object Microsoft.Exchange.WebServices.Data.ExtendedPropertyDefinition(0x65EB, [Microsoft.Exchange.WebServices.Data.MapiPropertyType]::String)
        $PR_PRIORITY = New-Object Microsoft.Exchange.WebServices.Data.ExtendedPropertyDefinition(0x0026, [Microsoft.Exchange.WebServices.Data.MapiPropertyType]::Integer)
        $psPropset = New-Object Microsoft.Exchange.WebServices.Data.PropertySet([Microsoft.Exchange.WebServices.Data.BasePropertySet]::IDOnly, $PR_RULE_MSG_NAME, $PR_RULE_MSG_PROVIDER, $PR_PRIORITY)

        # Add the property set to the item view
        $ItemView.PropertySet = $psPropset

        # Do the search and return the items
        $ruleResults = $inbox.FindItems($SearchFilter, $ItemView)

        # Check each rule directly from $ruleResults
        $FoundHidden = $false
        foreach ($rule in $ruleResults) {
            if ([string]::IsNullOrEmpty($rule.ExtendedProperties[0].Value) -or [string]::IsNullOrEmpty($rule.ExtendedProperties[1].Value)) {
                $priority = ($rule.ExtendedProperties | Where-Object { $_.PropertyDefinition.Tag -eq 38 }).Value
                Out-LogFile ("Possible Hidden Rule found in mailbox: " + $EmailAddress + " -- Rule Priority: " + $priority) -Notice
                $RuleOutput = $rule | Select-Object -Property ID, @{ Name = "Priority"; Expression = { ($rule.ExtendedProperties | Where-Object { $_.PropertyDefinition -like "*38*" }).Value } }
                $RuleOutput | Out-MultipleFileType -FilePrefix "EWS_Inbox_rule" -Txt -User $user -Append
                $FoundHidden = $true
            }
        }

        # Log if no hidden rules are found
        if ($FoundHidden -eq $false) {
            Out-LogFile ("No Hidden rules found for mailbox: " + $EmailAddress) -Information
        }
    }
}
