<#
.SYNOPSIS
    Starts the container.
.DESCRIPTION
    Starts a container.

    This script should be called from the Dockerfile as the ENTRYPOINT (or from within the ENTRYPOINT).

    It should be deployed to the root of the container image.
#>

param()

$env:IN_CONTAINER = $true
$PSStyle.OutputRendering = 'Ansi'

$mountedDrives = @(if (Test-Path '/proc/mounts') {
    (Select-String "\S+\s(?<p>\S+).+rw?,.+symlinkroot=/mnt/host" "/proc/mounts").Matches.Groups |
        Where-Object Name -eq p |
        Get-Item -path { $_.Value }
})
   
if ($global:ContainerInfo.MountedPaths) {
    "Mounted $($mountedDrives.Length) drives:" | Out-Host
    $mountedDrives | Out-Host
}

function / {

    "Hello from Fun."

    "It is $([DateTime]::Now.ToString())."

    "Here's a random number $([Random]::new().next())."
}



if ($args) {
    # If there are arguments, output them (you could handle them in a more complex way).
    $remainingArgs = @(foreach ($arg in $args) {
        if ($arg -match '\.ps1$' -and (Test-Path $arg)) {
            . $arg
        } else {
            $arg
        }
    })

    $fun = fun "http://*/" @remainingArgs
    # Launch three replicas
    $fun.Start();$fun.Start();$fun.Start()
} else {
    if (Test-Path ./Fun.fun.ps1) {
        . ./Fun.fun.ps1
    } else {
        function / { "Hello from Fun" }
    }
    $fun = fun "http://*/"
    # Launch three replicas
    $fun.Start();$fun.Start();$fun.Start()    
}


# If you want to do something when the container is stopped, you can register an event.
# This can call a script that does some cleanup, or sends a message as the service is exiting.
Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    Get-Job | 
        Where-Object HttpListener | 
        ForEach-Object {
            $_.HttpListener.Stop()
        }
    if (Test-Path '/Container.stop.ps1') {
        & /Container.stop.ps1 
    }    
} | Out-Null