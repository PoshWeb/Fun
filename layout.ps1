<#
.SYNOPSIS
    Layout
.DESCRIPTION
    This is a layout script.

    This is a simple and helpful convention for laying out content.

    Using a layout script gives you a consistent look and feel.

    Layout scripts should accept an object pipeline of input,
    and can have any number of additional parameters.

    Layout scripts are often aliased to `layout`.
.NOTES
    This is a simple convention.
    
    Just call your layout script `layout.ps1`, and alias it to `layout`.

    A layout script should accept any pipelined input.
    This is what we are laying out.

    Layout scripts may accept any number of additional parameters.
    This is how layout can be customized.

    Layout scripts can be copied and pasted or as custom as you want.
#>
param(
    # The title of the page.
    # This defaults an existing variable `$title`
    # or the current request url, replacing slashes with spaces.
    [string]$Title = $(
        @($Title, $page.Title, $site.Title, $env:Title, (
            $request.Url.LocalPath -replace '/', ' '
        ) -ne '')[0]
    ),
    
    # The description of the page.
    # This defaults to an existing variable `$description`
    [string]$Description = $Description,

    # The time the page was published.
    # This defaults to an existing `$publishedAt`
    # (as long as it is a `[DateTime]`) 
    $PublishedAt = $(
        if ($PublishedAt -as [DateTime]) {
            $PublishedAt -as [DateTime]
        }
    ),

    # A page image.
    # This defaults to an existing `$image` variable.
    $Image = $Image,

    # The name of the palette to use.
    [Alias('Palette')]
    [string]
    $PaletteName = $(
        if ($page.PaletteName) { $page.PaletteName }
        elseif ($site.PaletteName) { $site.PaletteName } 
        else { 'AdventureTime' }
    ),

    # The Google Font name.
    # This will be used for most elements.
    [Alias('FontName')]
    [string]
    $Font = $(
        if ($page.Font) { $page.Font }
        elseif ($site.Font) { $site.Font }
        elseif ($env:Font) { $env:Font }
        else { 'Roboto' }
    ),

    # The header font name
    # This will be used for `<h1>`,`<h2>`, `<h3>` elements.
    [string]
    $HeaderFont = $(
        if ($page.HeaderFont) { $page.HeaderFont }
        elseif ($site.HeaderFont) { $site.HeaderFont }
        elseif ($env:HeaderFont) { $env:HeaderFont }
        else { 'Nunito Sans' }
    ),

    # The Google Code Font name
    # This will be used for `<pre>` elements.
    [string]
    $CodeFont = $(
        if ($page.CodeFont) { $page.CodeFont }
        elseif ($site.CodeFont) { $site.CodeFont }
        elseif ($env:CodeFont) { $env:CodeFont }
        else { 'Inconsolata'} 
    ),

    [uri[]]
    $StyleSheet,

    [string]
    $AnalyticsId = $(
        if ($page.AnalyticsId) { $page.AnalyticsId }
        elseif ($site.AnalyticsId) { $site.AnalyticsId }
        elseif ($env:AnalyticsId) { $env:AnalyticsId }
        else { '' }
    ),

    # The repository being displayed.
    # This will default an existing `$repository`,
    # or the `$env:GH_REPOSITORY`
    [string]
    $Repository = $(
        if ($Repository) {
            $Repository
        } elseif ($env:GH_REPOSITORY) {
            $env:GH_REPOSITORY
        }
    ),

    $Footer = $(
        if ($footer) {
            $footer
        } else {
            [Ordered]@{
                "/contributing" = 'Contributing'
                "/code_of_conduct" = "Code of Conduct"
                "/security" = "Security"
            }
        }
    ),

    $Adknowledge = $(
        if ($Adknowledge) {
            $Adknowledge
        } else {            
            "<a href='https://PoshWeb.org/'>"
            # "<button class='adknowledge'>"
            "$(/PoshWeb.svg animated -First (Get-Random -Minimum 3 -Maximum 6))"
            # "</button>"
            "</a>"                    
        }
    )
)

filter htmlEncode { [Web.HttpUtility]::HtmlEncode("$_") }
filter attributEncode {[Web.HttpUtility]::HtmlAttributeEncode("$_")}
filter urlEncode {[Web.HttpUtility]::UrlEncode("$_")}

@(
"<html>"    
    "<head>"
        if ($AnalyticsId) {
            @"
<!-- Google tag (gtag.js) -->
<script async src="https://www.googletagmanager.com/gtag/js?id=$AnalyticsId"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());

  gtag('config', '$AnalyticsId');
</script>
"@
        }
        # Set the viewport so that we work decently well on mobile.
        '<meta name="viewport" content="width=device-width, initial-scale=1, minimum-scale=1.0" />'
        # Set the charset so emoji render 😉.
        '<meta charset="utf-8" />'

        # If we have a title
        if ($Title) {
            # set `<title>`
            "<title>$($title | htmlEncode)</title>"
            # and [OpenGraph](https://ogp.me) title.
            "<meta name='og:title' content='$($Title | attributEncode)' />"
        }

        # If we have a description
        if ($Description) {
            # more info for OpenGraph
            "<meta name='og:description' content='$($Description | attributEncode)' />"
        }


        if ($Image) {
            "<meta name='og:image' content='$($image | attributEncode)' />"
        }
        
        # * Color palette
        if ($PaletteName) {
            "<link rel='stylesheet' href='https://cdn.jsdelivr.net/gh/2bitdesigns/4bitcss@latest/css/$PaletteName.css' id='palette' />"
        }
        # * Google Font
        if ($Font) {
            "<link rel='stylesheet' href='https://fonts.googleapis.com/css?family=$Font' id='font' />"
        }
        if ($HeaderFont) {
            "<link rel='stylesheet' href='https://fonts.googleapis.com/css?family=$headerFont' id='headerFont' />"
        }

        # * Code font
        if ($CodeFont) {
            "<link rel='stylesheet' href='https://fonts.googleapis.com/css?family=$CodeFont' id='codeFont' />"
        }

        foreach ($sheet in $StyleSheet) {
            "<link rel='stylesheet' href='$sheet' />"
        }
        
        # Layouts often define custom styles        
        "<style>"
            /main.css -Font $font -HeaderFont $HeaderFont -CodeFont $CodeFont
        "</style>"
    "</head>"

    "<body>"
        "<header>"
            "<section class='header-left'>"
                "<a href='/'><button>$(. /_includes/FeatherIcon Home)</button></a>"
                if ($Repository) {
                    $Repository = $Repository -replace '^https://github.com/' -replace '.git$'
                    "<a href='https://github.com/$Repository'><button>$(. /_includes/FeatherIcon GitHub)</button></a>"
                } else {
                    "<a class='github' href='https://github.com/PoshWeb/Fun'><button>$(. /_includes/FeatherIcon GitHub)</button></a>"
                }
            "</section>"
            "<section class='header-middle'>"
            "</section>"
            "<section class='header-right'>"
                . /_includes/Palette -DefaultPalette $PaletteName
            "</section>"
            "<section class='header-progress'>"
            "</section>"
        "</header>"
        "<section class='main'>"
            if ($args) {
                "<section class='arguments'>"
                $args -join "`n"
                "</section>"
            }
            "<section class='output'>"
                $input -join "`n"
            "</section>"
        "</section>"
        "<footer class='end'>"            
            "<menu>"
                if ($Footer -is [Collections.IDictionary]) {
                    foreach ($footerItem in $Footer.GetEnumerator()) {
                        "<a href='$($footerItem.Key)'>$($footerItem.Value)</a>"
                    }
                }
            "</menu>"
            if ($Adknowledge) {
                "<section class='adknowledge'>$Adknowledge</section>"
            }
        "</footer>"
        "<footer class='fixed bottom scroll-progress'>"        
        "</footer>"
        . /_includes/CopyCode
    "</body>"
"</html>"
) -join "`n"
