$funHelp = Get-Help Fun

"# Fun"

"## $($funHelp.description.text -join [Environment]::Newline)"

$funHelp.alertset.alert.text -join [Environment]::Newline
