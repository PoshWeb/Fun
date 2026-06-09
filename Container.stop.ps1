<#
.SYNOPSIS
    Stops the container.
.DESCRIPTION
    This script is called when the container is about to stop.

    It can be used to perform any necessary cleanup before the container is stopped.
#>

"Thanks for having fun!", 
    "Hope you had fun!",
    "Fun is done",
    "Done with fun" |
        Get-Random | 
            Out-Host
