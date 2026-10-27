$funModule = Import-Module ./Fun.psd1 -Force -PassThru

$funJob = . ./Fun.fun.ps1
$funJob.Fun.Deploy()
