# HAWK + Github

## Who can contribute:
Everyone is welcome to contribute to this tool.  The goal of the Hawk tool is to be a community lead tool and provides
security support professionals with the tools they need to quickly and easily gather data from O365.

## What Hawk is and isn't
Hawk provides Limited analysis of the gathered data.  This is by design!
Hawk is here to help get all of the data in a single place it is not designed to make any significant
conclusions about this data.  This is intentional since it is impossible for the tool to know enough about
your environment or what you are concerned about to make a legitimate analysis of the data.

Hawk's goal is to quickly get you the data that is needed to come to a conclusion; not to make the conclusion for you.

## How can I contribute:
Please post any issues you find to the Issue section.

# HAWK
Powershell Based tool for gathering information related to M365 intrusions and potential Breaches

## PURPOSE:
The Hawk module has been designed to ease the burden on M365 administrators who are performing
a Cloud forensic analysis for their organization.

It does NOT take the place of a human reviewing the data generated and is simply here to make
data gathering easier.

## HOW TO USE:
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

## Disclaimer
Hawk is NOT an official MICROSOFT tool.  Therefore use of the tool is covered exclusively by the license associated with this github repository.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.