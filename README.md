# hawk
Powershell Based tool for gathering information related to O365 intrusions and potential Breaches

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
