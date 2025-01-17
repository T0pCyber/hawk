Function Write-HawkBanner {
    <#
    .SYNOPSIS
        Displays the Hawk welcome banner in the terminal.

    .DESCRIPTION
        The `Write-HawkBanner` function displays a visually appealing ASCII art banner 
        when starting Hawk operations. The banner includes the Hawk logo and additional 
        information about the tool. Optionally, the function can display a welcome 
        message to guide users through the initial setup process.

    .PARAMETER DisplayWelcomeMessage
        This optional switch parameter displays a series of informational messages 
        to help the user configure their investigation environment.

    .INPUTS
        None. The function does not take pipeline input.

    .OUTPUTS
        [String]
        The function outputs the Hawk banner as a string to the terminal.

    .EXAMPLE
        Write-HawkBanner
        Displays the Hawk welcome banner without the welcome message.

    .EXAMPLE
        Write-HawkBanner -DisplayWelcomeMessage
        Displays the Hawk welcome banner followed by a welcome message that guides 
        the user through configuring the investigation environment.
    #>
    [CmdletBinding()]
    param(
        [Switch]$DisplayWelcomeMessage
    )
    
    $banner = @'
========================================
    __  __               __   
   / / / /___ __      __/ /__ 
  / /_/ / __ `/ | /| / / //_/
 / __  / /_/ /| |/ |/ / ,<   
/_/ /_/\__,_/ |__/|__/_/|_|  

========================================
                             
Microsoft Cloud Security Analysis Tool
https://cloudforensicator.com

========================================

'@

    Write-Output $banner 

    if ($DisplayWelcomeMessage) {
        Write-Information "Welcome to Hawk! Let's get your investigation environment set up."
        Write-Information "We'll guide you through configuring the output file path and investigation date range."
        Write-Information "You'll need to specify where logs should be saved and the time window for data retrieval."
        Write-Information "If you're unsure, don't worry! Default options will be provided to help you out."
        Write-Information "`nLet's get started!`n"
    }

}