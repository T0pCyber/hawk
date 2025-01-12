Function Write-HawkBanner {
    <#
    .SYNOPSIS
        Displays the Hawk welcome banner.
    .DESCRIPTION
        Displays an ASCII art banner when starting Hawk operations.
        The banner is sized to fit most terminal windows.
    .EXAMPLE
        Write-HawkBanner
        Displays the Hawk welcome banner
    #>
    [CmdletBinding()]
    param()
    
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

    Write-Information "Welcome to Hawk! Let's get your investigation environment set up."
    Write-Information "We'll guide you through configuring the output file path and investigation date range."
    Write-Information "You'll need to specify where logs should be saved and the time window for data retrieval."
    Write-Information "If you're unsure, don't worry! Default options will be provided to help you out."
    Write-Information "`nLet's get started!`n"


}