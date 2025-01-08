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

'@

    Write-Output $banner 
}