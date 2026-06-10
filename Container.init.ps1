<#
.SYNOPSIS
    Initializes a container during build.
.DESCRIPTION
    Initializes the container image with the necessary modules and packages.

    The scripts arguments can be provided with either an `ARG` or `ENV` instruction in the Dockerfile.
#>

param(
# The name of the module to be installed.
[string]$ModuleName = $(
    if ($env:ModuleName) { $env:ModuleName }
    else { 'Fun' }
),
# The modules to be installed.
[string[]]$InstallModules = @(
    if ($env:InstallModules) { $env:InstallModules -split ',' }
)
)

# Get the root module directory
$rootModuleDirectory = @($env:PSModulePath -split '[;:]')[0]

# Determine the path to the module destination. 
$moduleDestination = "$rootModuleDirectory/$ModuleName"
# Copy the module to the destination
# (this is being used instead of the COPY statement in Docker, to avoid additional layers).
Copy-Item -Path "$psScriptRoot" -Destination $moduleDestination -Recurse -Force

# Copy all container-related scripts to the root of the container.
Get-ChildItem -Path $PSScriptRoot | 
    Where-Object Name -Match '^Container\..+?\.ps1$' | 
    Copy-Item -Destination /

# Create a new profile
New-Item -Path $Profile -ItemType File -Force |
    # and import this module in the profile
    Add-Content -Value "Import-Module $ModuleName" -Force
# If we have modules to install
if ($InstallModules) { 
    # Install the modules
    Install-Module -Name $InstallModules -Force -AcceptLicense -Scope CurrentUser 
    # and import them in the profile
    Add-Content -Path $Profile -Value "Import-Module '$($InstallModules -join "','")'" -Force
}
# In our profile, push into the module's directory
Add-Content -Path $Profile -Value "Get-Module $ModuleName | Split-Path | Push-Location" -Force

# Remove the .git directories from any modules
Get-ChildItem -Path $rootModuleDirectory -Directory -Force -Recurse |
    Where-Object Name -eq '.git' |
    Remove-Item -Recurse -Force

# Congratulations! You have successfully initialized the container image.
# This script should work in about any module, with minor adjustments.
# If you have any adjustments, please put them below here, in the `#region Custom`

#region Custom

#endregion Custom

