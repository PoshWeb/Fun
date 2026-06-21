<#
.SYNOPSIS
    Includes Feather Icons
.DESCRIPTION
    Includes a feather icon in the site.
.NOTES
    Icons will be cached in memory to avoid repeated CDN requests.
.EXAMPLE
    /_includes/FeatherIcon clipboard
.LINK
    https://feathericons.com/
#>
[OutputType('image/svg+xml')]
param(
# The feather icon name
[string]
$Icon = 'terminal',

[uri]
$FeatherCDN = "https://cdn.jsdelivr.net/gh/feathericons/feather@latest/icons/"
)

if (-not $script:FeatherIconCache) {
    $script:FeatherIconCache = [Ordered]@{}
}

$iconUri =
    (
        $FeatherCDN -replace '^https?://' -replace '^',
            'https://' -replace '/$'
    ), (
        $icon.ToLower() -replace '\.svg$' -replace '^/' -replace '$' -replace '\s',
            '-' -replace '$', '.svg'
    ) -join '/'

if (-not $script:FeatherIconCache[$iconUri]) {
    $script:FeatherIconCache[$iconUri] = try {
        Invoke-RestMethod $iconUri
    } catch {
        Write-Warning "Could not get $iconUri : $_"
    }
}

$script:FeatherIconCache[$iconUri].OuterXml
