<#
.SYNOPSIS
    Show Hawk Help and creates the Hawk_Help.txt file
.DESCRIPTION
    Show Hawk Help and creates the Hawk_Help.txt file
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
#>
Function Show-HawkHelp {

    Out-LogFile "Creating Hawk Help File"

    $help = "BASIC USAGE INFORMATION FOR THE HAWK MODULE
	===========================================
	Hawk is in constant development.  We will be adding addtional data gathering and information analysis.
	DISCLAIMER:
	===========================================
	THE SAMPLE SCRIPTS ARE NOT SUPPORTED UNDER ANY MICROSOFT STANDARD SUPPORT
	PROGRAM OR SERVICE. THE SAMPLE SCRIPTS ARE PROVIDED AS IS WITHOUT WARRANTY
	OF ANY KIND. MICROSOFT FURTHER DISCLAIMS ALL IMPLIED WARRANTIES INCLUDING, WITHOUT
	LIMITATION, ANY IMPLIED WARRANTIES OF MERCHANTABILITY OR OF FITNESS FOR A PARTICULAR
	PURPOSE. THE ENTIRE RISK ARISING OUT OF THE USE OR PERFORMANCE OF THE SAMPLE SCRIPTS
	AND DOCUMENTATION REMAINS WITH YOU. IN NO EVENT SHALL MICROSOFT, ITS AUTHORS, OR
	ANYONE ELSE INVOLVED IN THE CREATION, PRODUCTION, OR DELIVERY OF THE SCRIPTS BE LIABLE
	FOR ANY DAMAGES WHATSOEVER (INCLUDING, WITHOUT LIMITATION, DAMAGES FOR LOSS OF BUSINESS
	PROFITS, BUSINESS INTERRUPTION, LOSS OF BUSINESS INFORMATION, OR OTHER PECUNIARY LOSS)
	ARISING OUT OF THE USE OF OR INABILITY TO USE THE SAMPLE SCRIPTS OR DOCUMENTATION,
	EVEN IF MICROSOFT HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES
	PURPOSE:
	===========================================
	The Hawk module has been designed to ease the burden on O365 administrators who are performing
	a forensic analysis in their organization.
	It does NOT take the place of a human reviewing the data generated and is simply here to make
	data gathering easier.
	HOW TO USE:
	===========================================
	Hawk is divided into two primary forms of cmdlets; user based Cmdlets and Tenant based cmdlets.
	User based cmdlets take the form Verb-HawkUser<action>.  They all expect a -user switch and
	will retrieve information specific to the user that is specified.  Tenant based cmdlets take
	the form Verb-HawkTenant<Action>.  They don't need any switches and will return information
	about the whole tenant.
	A good starting place is the Start-HawkTenantInvestigation this will run all the tenant based
	cmdlets and provide a collection of data to start with.  Once this data has been reviewed
	if there are specific user(s) that more information should be gathered on
	Start-HawkUserInvestigation will gather all the User specific information for a single user.
	All Hawk cmdlets include help that provides an overview of the data they gather and a listing
	of all possible output files.  Run Get-Help <cmdlet> -full to see the full help output for a
	given Hawk cmdlet.
	Some of the Hawk cmdlets will flag results that should be further reviewed.  These will appear
	in _Investigate files.  These are NOT indicative of unwanted activity but are simply things
	that should reviewed.
	REVIEW HAWK CODE:
	===========================================
	The Hawk module is written in PowerShell and only uses cmdlets and function that are availble
	to all O365 customers.  Since it is written in PowerShell anyone who has downloaded it can
	and is encouraged to review the code so that they have a clear understanding of what it is doing
	and are comfortable with it prior to running it in their environment.
	To view the code in notepad run the following command in powershell:
		notepad (join-path ((get-module hawk -ListAvailable)[0]).modulebase 'Hawk.psm1')
	To get the path for the module for use in other application run:
		((Get-module Hawk -listavailable)[0]).modulebase"

    $help | Out-MultipleFileType -FilePrefix "Hawk_Help" -txt

    Notepad (Join-Path $hawk.filepath "Tenant\Hawk_Help.txt")

}
