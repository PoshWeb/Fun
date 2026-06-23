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
        if ($Title) {
            $Title
        } elseif ($request.Url.LocalPath) {
            $request.Url.LocalPath -replace '/', ' '
        }
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
    $PaletteName = 'AdventureTime',

    # The Google Font name.
    # This will be used for most elements.
    [Alias('FontName')]
    [string]
    $Font = 'Roboto',

    # The Google Code Font name
    # This will be used for `<pre>` elements.
    [string]
    $CodeFont = 'Inconsolata',

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
                "Contributing" = '/contributing'
                "Code of Conduct" = "/code-of-conduct"
                "Security" = "/security"
            }
        }
    ),

    $Adknowledge = $(
        if ($Adknowledge) {
            $Adknowledge
        } else {
            "* A <a href='https://github.com/PoshWeb'>PoshWeb</a> Project"
        }
    )
)

filter htmlEncode { [Web.HttpUtility]::HtmlEncode("$_") }
filter attributEncode {[Web.HttpUtility]::HtmlAttributeEncode("$_")}
filter urlEncode {[Web.HttpUtility]::UrlEncode("$_")}

@(
"<html>"    
    "<head>"
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
        # * Code font
        if ($CodeFont) {
            "<link rel='stylesheet' href='https://fonts.googleapis.com/css?family=$CodeFont' id='codeFont' />"
        }
        
        # Layouts often define custom styles        
        "<style>"

            # In this case we want a full screen body element  
            "body {"
                @(
                    "max-width:100vw"
                    "height: 100vh"
                    "margin-left: auto"
                    "margin-right: auto"
                    # which displays inner content in a grid
                    "display:grid"
                    # with autosized top and bottom and a flexibly sized middle
                    "grid-template-rows: auto, 1fr, auto"
                    # and used the font we provided (falling back to sans-serif).
                    "font-family: '$Font', sans-serif;"
                ) -join ';'
            "}"

            # Main content we want to "nudge in" a bit.
            ".main { width: 80%; margin-left:auto; margin-right: auto }"

            # `h1`, `h2`, `h3` are centered with slight font size and line height adjustments
            "h1 { text-align: center; font-size: 4rem; line-height: 5rem;}"
            "h2 { text-align: center; font-size: 2rem; line-height: 3rem; }"
            "h3 { text-align: center; font-size: 1.5rem; line-height: 2rem; }"


            # `footer`
            "footer {"
                @(
                    "margin-top: 2vh" # has a vertical margin to make it stand out.
                ) -join ';'                
                "ul li { list-style-type: none; display: inline; }"
            "}"

            # `footer menu`
            "footer menu {"
                @(
                    # display as a grid
                    "display: grid"                    
                    "grid-template-columns: repeat(auto-fit, minmax(200px, 1fr))"                    
                    "justify-items: center"
                    "justify-content: space-between"                    
                ) -join ';'
            "}"

            ".adknowledge { text-align: right; font-size: 0.9rem; margin-right: 1rem; margin-bottom: 1rem; }"

            # `a` anchors do not get text decoration
            "a, a:visited { text-decoration: none; }"
            # unless they are focused or hovered
            "a:hover, a:focus {text-decoration: underline;}"

            # `select` and `button` should hover
            "select:hover, button:hover { cursor: pointer }"

            # The `header` should be a fixed grid
            "header {"
                "position: fixed",
                "display: grid",
                "grid-template-areas: $(
                    '"header-left header-middle header-right"',
                    '"header-progress header-progress header-progress"' -join (
                        [Environment]::NewLine
                    )
                )",
                "grid-template-rows: auto, auto",
                "grid-template-columns: auto 1fr auto",
                "top:0",
                "width: 100%" -join ';'
            "}"
            
            # Arrange the various headers
            ".header-left{ grid-area: header-left; text-align: left; }"
            ".header-middle { grid-area: header-middle; flex:1; text-align: center; }"
            ".header-right { grid-area: header-right; text-align: right; margin-left: auto; }"
            ".header-progress { grid-area: header-progress; }"

            # Render code and pre elements in our code font, fall back to monospace.
            "pre, code { font-family: '$CodeFont', monospace; }"

            # Include our highlight colors.
            /_includes/HighlightColors
            
            "@keyframes grow-progress { from { transform: scaleX(0); } to { transform: scaleX(1); } }"
            ".header-progress {grid-area: header-middle; width: 100%; height: .5em; background: var(--foreground); transform-origin: 0 50%;
                animation: grow-progress auto linear;
                animation-timeline: scroll();}"            
            
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
        "<footer>"            
            "<menu>"
                if ($Footer -is [Collections.IDictionary]) {
                    foreach ($footerItem in $Footer.GetEnumerator()) {
                        "<a href='$($footerItem.Value)'><button>$($footerItem.Key)</button></a>"
                    }
                }                
            "</menu>"
            "<section class='adknowledge'>$Adknowledge</section>"            
        "</footer>"

        . /_includes/CopyCode
    "</body>"
"</html>"
) -join "`n"
