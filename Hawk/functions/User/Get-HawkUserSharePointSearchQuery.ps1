Function Get-HawkUserSharePointSearchQuery {
    <#
    .SYNOPSIS
        This will export SearchQueryInitiatedSharePoint operations from the Unified Audit Log (UAL). Must be connected to Exchange Online
        using the Connect-EXO or Connect-ExchangeOnline module. M365 E5 or G5 license is required for this function to work.
        This telemetry will ONLY be availabe if Advanced Auditing is enabled for the M365 user.
    .DESCRIPTION
        This function tracks searches performed in SharePoint, providing visibility into user search behavior across 
        sensitive documents and sites.
    .PARAMETER UserPrincipalName
        Specific user(s) to be investigated
    .EXAMPLE
        Get-HawkUserSharePointSearchQuery -UserPrincipalName bsmith@contoso.com
        Returns send activity queries from Unified Audit Log (UAL) that correspond to the UserPrincipalName that is provided
    .OUTPUTS
        SharePointSearches_bsmith@contoso.com.csv /json
        Simple_SharePointSearches_bsmith@contoso.com.csv/json
    
    .LINK
        https://www.microsoft.com/security/blog/2020/12/21/advice-for-incident-responders-on-recovery-from-systemic-identity-compromises/
    
    .NOTES
        "Operation Properties" and "Folders" will return "System.Object" as they are nested JSON within the AuditData field.
        You will need to conduct individual log pull and review via PowerShell or other SIEM to determine values
        for those fields.
    #>
        [CmdletBinding()]
        param(
            [Parameter(Mandatory=$true)]
            [array]$UserPrincipalName
        )
    
        BEGIN {
            # Check if Hawk object exists and is fully initialized
            if (Test-HawkGlobalObject) {
                Initialize-HawkGlobalObject
            }
            Out-LogFile "Starting Unified Audit Log (UAL) search for 'SearchQueryInitiatedSharePoint'" -Action
            Out-LogFile "Please be patient, this can take a while..." -Information
            Test-EXOConnection
        }#End Begin
    
        PROCESS {
            
            #Verify UPN input
            [array]$UserArray = Test-UserObject -ToTest $UserPrincipalName
    
            foreach($UserObject in $UserArray) {
                [string]$User = $UserObject.UserPrincipalName
                
                # Verify that user has operation enabled for auditing. Otherwise, move onto next user.
                if (Test-OperationEnabled -User $User -Operation 'SearchQueryInitiated') {
                    Out-LogFile "Operation 'SearchQueryInitiated' verified enabled for $User." -Information
                    try {
                        #Retrieve all audit data for SharePoint search activity
                        $SearchCommand = "Search-UnifiedAuditLog -Operations 'SearchQueryInitiatedSharePoint' -UserIds $User"
                        $SharePointSearches = Get-AllUnifiedAuditLogEntry -UnifiedSearch $SearchCommand
                        
                        if ($SharePointSearches.Count -gt 0){
                            
                            #Define output directory path for user
                            $UserFolder = Join-Path -Path $Hawk.FilePath -ChildPath $User
        
                            #Create user directory if it doesn't already exist
                            if (-not (Test-Path -Path $UserFolder)) {
                                New-Item -Path $UserFolder -ItemType Directory -Force | Out-Null
                            }
        
                            #Compress raw data into more simple view
                            $SharePointSearchesSimple = $ExchangeSends | Get-SimpleUnifiedAuditLog
        
                            #Export both raw and simplistic views to specified user's folder
                            $SharePointSearches | Select-Object -ExpandProperty AuditData | Convertfrom-Json | Out-MultipleFileType -FilePrefix "SharePointSearches_$User" -User $User -csv -json
                            $SharePointSearchesSimple | Out-MultipleFileType -FilePrefix "Simple_SharePointSearches_$User" -User $User -csv -json
                        } else {
                            Out-LogFile "Get-HawkUserSharePointSearchQuery completed successfully" -Information
                            Out-LogFile "No items found for $User." -Information
                        }
                    } catch {
                        Out-LogFile "Error processing SharePoint Search Activity for $User : $_" -isError
                        Write-Error -ErrorRecord $_ -ErrorAction Continue
                    }
                } else {
                    Out-LogFile "Operation 'SearchQueryInitiated' is not enabled for $User." -Information
                    Out-LogFile "No data recorded for $User." -Information
                }
            }
            
        }#End Process
    
        END{
            Out-Logfile "Completed exporting SharePoint Search Activity logs" -Information
        }#End End
    
    }