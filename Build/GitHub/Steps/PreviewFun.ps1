<#
.SYNOPSIS
    Preview Fun
.DESCRIPTION

#>

Import-Module .\Fun.psd1 -PassThru | Out-Host
. .\Fun.fun.ps1 deploy "preview"