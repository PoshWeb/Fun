<#
.SYNOPSIS
    Preview Fun
.DESCRIPTION

#>
if ($PSScriptRoot -notmatch '/_temp') {
    Push-Location ($PSScriptRoot | Split-Path | Split-Path | Split-Path)
}
Import-Module .\Fun.psd1 -PassThru | Out-Host
. .\Fun.fun.ps1 deploy "preview"
if ($PSScriptRoot -notmatch '/_temp') {
    Pop-Location
}