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
	Single UPN of a user, commans seperated list of UPNs, or array of objects that contain UPNs.

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

	Get-HawkUserHiddenRules -UserPrincipalName user@contoso.com -EWSCredential (get-credential)

	Searches user@contoso.com looking for hidden inbox rules using the provided credentials

	.EXAMPLE

	Get-HawkUserHiddenRules -UserPrincipalName (get-mailbox -Filter {Customattribute1 -eq "C-level"})

	Looks for hidding inbox rules for all users who have "C-Level" set in CustomAttribute1

	
	#>
    param
    (
        [Parameter(Mandatory = $true)]
        [array]$UserPrincipalName,
        [switch]$UseImpersonation,
        $EWSCredential
	
    )
	
    Test-EXOConnection
    Send-AIEvent -Event "CmdRun"

    # Verify our UPN input
    [array]$UserArray = Test-UserObject -ToTest $UserPrincipalName
	
    # Process thru each object recieved
    foreach ($Object in $UserArray) {

        # Push the UPN into $user for ease of use
        $user = $object.UserPrincipalName

        # Determine if the email address is null or empty
        # If it is write a warning and skip the rest of the script
        [string]$EmailAddress = (get-mailbox $user).primarysmtpaddress
        if ([string]::IsNullOrEmpty($EmailAddress)) { 
            Write-Warning "No SMTP Address found Skipping"
            Return $null
        }

        # If we don't have a credential object then ask for creds and push them into the global scope
        if ($null -eq $EWSCredential) {
            Out-LogFile "Please provide credentials that have impersonation rights to the mailbox you are looking to check"
            $EWSCredential = Get-Credential
        }

        # Import the EWS Managed API
        if (Test-Path 'C:\Program Files\Microsoft\Exchange\Web Services\2.2\Microsoft.Exchange.WebServices.dll') {
            Out-LogFile "Ews Managed API Found"
        }
        else { 
            Write-Error "Please install EWS Managed API 2.2 `nhttp://www.microsoft.com/en-us/download/details.aspx?id=42951" -ErrorAction Stop
        }
		
        # Import the EWS managed API dll
        Import-Module 'C:\Program Files\Microsoft\Exchange\Web Services\2.2\Microsoft.Exchange.WebServices.dll'

        # Set up the EWS Connection
        Write-Host ("Setting up connection for " + $emailaddress) -ForegroundColor Green
        $exchService = New-Object Microsoft.Exchange.WebServices.Data.ExchangeService -ArgumentList ([Microsoft.Exchange.WebServices.Data.ExchangeVersion]::Exchange2013_Sp1)
        $exchService.Credentials = New-Object  Microsoft.Exchange.WebServices.Data.WebCredentials($EWSCredential.username, $EWSCredential.GetNetworkCredential().password);

        # If we have the global URL for EWS then we just use it since it should all be the same in this case
        # Otherwise we need to get it via autodiscover
        if ($null -eq $EWSUrl) {
            $exchService.AutodiscoverUrl($emailAddress, { $true })
            $exchService.url | Set-Variable -name EWSUrl -Scope Global
        }
        else {
            $exchService.url = $EWSUrl
        }

        # Set the connection up for impersonation so that we log into the mailbox we want not the one we have creds for
        $exchService.ImpersonatedUserId = New-Object Microsoft.Exchange.WebServices.Data.ImpersonatedUserId([Microsoft.Exchange.WebServices.Data.ConnectingIdType]::SmtpAddress, $emailAddress);

        # Add the Anchor mailbox to the http header
        $exchService.HttpHeaders.Add("X-AnchorMailbox", [string]$EmailAddress)

        # Using the exchService object connect and retrieve all inbox rules
        # This DID NOT work since it didn't pull back the hidden rule
        # $rules = $exchService.GetInboxRules($EmailAddress)

        # Bind to the inbox folder
        try {
            $inbox = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($exchService, [Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::Inbox)	
        }
        catch {
            # If we don't have rights to impersonate throw in the log file and provide a better error
            if ($_.Exception.innerexception -like "*permission to impersonate*") {
                Out-LogFile ("[ERROR] - Account does not have Impersonation Rights on Mailbox: " + $EmailAddress)
                Out-LogFile "https://docs.microsoft.com/en-us/exchange/client-developer/exchange-web-services/how-to-configure-impersonation"
                Write-Error $_ -ErrorAction Stop
            }
            # If it isn't an impersonation error throw it and stop
            else {
                Write-Error $_ -ErrorAction Stop
            }
        }		

        # Setup the search
        $SearchFilter = new-object Microsoft.Exchange.WebServices.Data.SearchFilter+IsEqualTo([Microsoft.Exchange.WebServices.Data.ItemSchema]::ItemClass, "IPM.Rule.Version2.Message")
        $Itemview = new-object Microsoft.Exchange.WebServices.Data.ItemView(500)
        $ItemView.Traversal = [Microsoft.Exchange.Webservices.Data.ItemTraversal]::Associated

        # Create our property set to view
        $PR_RULE_MSG_NAME = New-Object Microsoft.Exchange.WebServices.Data.ExtendedPropertyDefinition(0x65EC, [Microsoft.Exchange.WebServices.Data.MapiPropertyType]::String) 
        $PR_RULE_MSG_PROVIDER = New-Object Microsoft.Exchange.WebServices.Data.ExtendedPropertyDefinition(0x65EB, [Microsoft.Exchange.WebServices.Data.MapiPropertyType]::String)
        $PR_PRIORITY = New-Object Microsoft.Exchange.WebServices.Data.ExtendedPropertyDefinition(0x0026, [Microsoft.Exchange.WebServices.Data.MapiPropertyType]::Integer)
        $psPropset = new-object Microsoft.Exchange.WebServices.Data.PropertySet([Microsoft.Exchange.WebServices.Data.BasePropertySet]::IDOnly, $PR_RULE_MSG_NAME, $PR_RULE_MSG_PROVIDER, $PR_PRIORITY)

        # Add the property set to the item view
        $ItemView.PropertySet = $psPropset

        # Do the search and return the items
        $ruleResults = $inbox.finditems($SearchFilter, $Itemview)

        # Null our return arry and populate it
        [array]$ruleArray = $null
        $ruleResults | ForEach-Object { [array]$ruleArray += $_ }

        # Set our found flag to false
        $FoundHidden = $false

        # Check each rule
        Foreach ($rule in $ruleArray) {
			
            # If either Rule Name or Rule Provider are null then we need to flag it and return the priority of the rule
            if ([string]::IsNullOrEmpty($rule.ExtendedProperties[0].value) -or [string]::IsNullOrEmpty($rule.ExtendedProperties[1].value)) {
                $priority = ($rule.ExtendedProperties | Where-Object { $_.propertydefinition.tag -eq 38 }).value
                Out-LogFile ("Possible Hidden Rule found in mailbox: " + $EmailAddress + " -- Rule Priority: " + $priority) -notice
                $RuleOutput = $rule | Select-Object -Property ID, @{Name = "Priority"; Expression = { ($rule.ExtendedProperties | where { $_.propertydefinition -like "*38*" }).value } }
                $RuleOutput | Out-MultipleFileType -FilePrefix "EWS_Inbox_rule" -txt -user $user -append
                $FoundHidden = $true
            }
			
        }
		
        # If the flag wasn't set then we need to log that we didn't find any hidden rules for th euser
        if ($FoundHidden -eq $false) {
            Out-LogFile ("No Hidden rules found for mailbox: " + $EmailAddress)
        }

        # return $ruleArray
    }
	



}

   