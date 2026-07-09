<#
.SYNOPSIS
    Fun css    
.DESCRIPTION
    Generates a css stylesheet for fun. 
.EXAMPLE
    ./Fun.css.ps1 > ./Fun.css
#>
[OutputType('text/css')]
param(
# The Google Font name.
# This will be used for most elements.
[Alias('FontName')]
[string]
$Font = $(
    if ($page.Font) { $page.Font }        
    elseif ($site.Font) { $site.Font }
    elseif ($env:Font) { $env:Font }
    else { 'Roboto'}
),

# The header font name
# This will be used for `<h1>`,`<h2>`, `<h3>` elements.
[string]
$HeaderFont = $(
    if ($page.HeaderFont) { $page.HeaderFont }
    elseif ($site.HeaderFont) { $site.HeaderFont }
    elseif ($env:HeaderFont) { $env:HeaderFont }
    else { 'Nunito Sans'}
),

# The Google Code Font name
# This will be used for `<pre>` elements.
[string]
$CodeFont = $(
    if ($page.CodeFont) { $page.CodeFont }
    elseif ($site.CodeFont) { $site.CodeFont }
    elseif ($env:CodeFont) { $env:CodeFont }
    else { 'Inconsolata' }
)
)
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
        "font-family: '$Font', sans-serif"        
        "background-image:$(        
            $alpha = "4.2%"
            $colors = 'var(--foreground)','transparent'            
            $randomPositions = foreach ($n in 1..(Get-Random -Min 2 -Max 5)) {
                "$(
                    Get-Random -Minimum 1 -Maximum 99
                )% $(
                    Get-Random -Minimum 1 -Maximum 99
                )%"
            }
            @(foreach ($position in $randomPositions) {
                "repeating-radial-gradient($(@(
                    "ellipse $(
                        Get-Random -Min 40 -Max 60
                    )% $(
                        Get-Random -Min 40 -Max 60
                    )% at $position"
                    $colorNumber = 0
                    $bandSize = Get-Random -Minimum 4 -Maximum 8
                    foreach ($color in $colors) {
                        $colorNumber++
                        "color-mix(in srgb, $color $alpha, transparent) $($colorNumber * $bandSize)rem"
                    }                    
                ) -join ',' + [Environment]::NewLine))"
            }) -join (',' + [Environment]::NewLine)
)" 

    ) -join ';'
"}"

# Main content we want to "nudge in" a bit.
".main { width: 80%; margin-left:auto; margin-right: auto }"

# `h1`, `h2`, `h3` are centered with slight font size and line height adjustments
"header h1, header h2, header h3 { text-align: center; font-family: '$HeaderFont', sans-serif; letter-spacing: 0.1rem; }"    

"h1 { text-align: center; font-size: 4rem; line-height: 5rem}"
"h2 { text-align: center; font-size: 2rem; line-height: 3rem}"
"h3 { font-size: 1.5rem; line-height: 2rem }"

# `footer`
"footer {"
    @(
        "margin-top: 2vh;" # has a vertical margin to make it stand out.
    ) -join ';'                
    "ul li { list-style-type: none; display: inline; }"
"}"

".fixed { position: fixed; }"
".bottom { bottom: 0 }"
".top { top: 0 }"
".left { left: 0 }"
".right { right: 0 }"
".end { margin-bottom: 3rem }"

"button { border-radius: 4.2%; }"
"select { border-radius: 4.2% }"

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
"* { box-sizing: border-box }"

# The `header` should be a fixed grid
"header {"
    "position: fixed",
    "display: grid",
    "grid-template-areas: '$("header-left header-middle header-right")'",
    "grid-template-columns: auto 1fr auto",
    "padding: 0.5rem",
    "top:0",
    "width: 100%" -join ';'
"}"

"p {line-height: 1.5rem }"

"@keyframes grow-progress { from { transform: scaleX(0); } to { transform: scaleX(1); } }"
# Arrange the various headers
".header-left{ grid-area: header-left; text-align: left; }"
".header-middle { grid-area: header-middle; flex:1; text-align: center; }"
".header-right { grid-area: header-right; text-align: right; margin-left: auto; }"
".scroll-progress {"
    "grid-area: header-middle",
    "width: 100%",
    "height: 1rem",
    "margin-top: auto",
    "margin-bottom: auto",
    "transform-origin: 0 50%",    
    "background: linear-gradient(to right, transparent, var(--foreground))",
    "animation: grow-progress auto linear",
    "animation-timeline: scroll()" -join ';'
"}"

# Render code and pre elements in our code font, fall back to monospace.
"pre, code { font-family: '$CodeFont', monospace; }"
"code { padding: 0.5rem }"

# Include our highlight colors.
/_includes/HighlightColors

