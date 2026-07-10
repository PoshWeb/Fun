<#
.SYNOPSIS
    Includes a palette selector
.DESCRIPTION
    Includes a palette selector and randomized palette switcher.
    
    This allows the page to use multiple color palettes.
#>
param(
# The source for all palette information
[uri]
$AllPalettesSource = 'https://4bitcss.com/Palettes.json',

# The Palette CDN.  This is the root URL of all palettes.
[uri]
$PaletteCDN = 'https://cdn.jsdelivr.net/gh/2bitdesigns/4bitcss@latest/css/',

# The identifier for the palette `<select>`.
[string]
$SelectPaletteId = 'SelectPalette',

# The identifier for the stylesheet.  By default, palette.
[string]
$PaletteId = 'palette',

[string]
$DefaultPalette = $(
    if ($page.Palette) {
        $page.Palette
    } elseif ($site.Palette) {
        $site.Palette
    }
    else {
        ''
    }
)
)


$JavaScript = @"
function SetPalette(event) {
    var palette = document.getElementById('$PaletteId')
    if (! palette) {
        palette = document.createElement('link')
        palette.rel = 'stylesheet'
        palette.id = 'palette'
        document.head.appendChild(palette)
    }
    var selectedPalette = event.target.value
    palette.href = '$PaletteCDN' + selectedPalette + '.css'
}
"@

if (-not $script:AllPalettes) {
    $script:AllPalettes = Invoke-RestMethod $AllPalettesSource
}

if (-not $script:Cache) {
    $script:Cache = [Ordered]@{}
}


$paletteSquare = "
<svg xmlns='http://www.w3.org/2000/svg' width='24' height='24' viewBox='0 0 24 24'>
    $(
        $colors = 
            'black', 'red', 'green', 'blue', 'yellow', 'cyan', 'purple', 'white'

        $colors = @($colors) + @(
            foreach ($color in $colors) {
                "bright$(
                    $color.Substring(0,1).ToUpper()                    
                )$($color.Substring(1))"
            }
        )
        for ($colorNumber =0;$colorNumber -lt $colors.Count; $colorNumber++) {
            $row = [Math]::Floor($colorNumber / 4)
            $column = $colorNumber % 4
            $color = $colors[$colorNumber]
            "<path fill='transparent' class='$($color)-stroke $($color)-fill' d='$(
                # Move to our row / column
                "m $($column * 5) $($row * 5)"
                # and draw a square
                "h 6 v 6 h -6 v -6"
            )' />"
        } 
    )    
</svg>
"

$paletteSelector = @"
<style>

.palette-controls {
    display: flex;
    flex-direction: row;
    place-items: center;
    justify-items: center;
    justify-content: space-between;
}

.palette-controls * {
    height: 2rem;
}

.invisible { display: none; }
</style>

<section class='palette-controls'>
<select id='$SelectPaletteId' onchange='SetPalette(event)'>
$(    
    foreach ($palette in $script:AllPalettes.psobject.Properties) {
        $paletteName = $palette.name
        $palette = $palette.value
        $selectedPalette = if ($defaultPalette -and $defaultPalette -eq $paletteName) { " selected='true'"} else { '' }
        "<option data-luma='$($palette.luma)' value='$([Web.HttpUtility]::HtmlAttributeEncode($paletteName))'$selectedPalette>$([Web.HttpUtility]::HtmlEncode($paletteName))</option>"
    }
)
</select>
<button class='random-palette-button' command='--random-palette' id='random-palette-button' commandfor='$SelectPaletteId'>$(
    /_includes/FeatherIcon -Icon refresh-cw
    $paletteSquare
)</button>
</section>
<script>
document.getElementById('$selectPaletteId').addEventListener('command', (event)=> {
    if (event.command == '--random-palette') {
        var SelectPalette = event.target        
        var randomNumber = Math.floor(
            Math.random() * SelectPalette.length
        )        
        SelectPalette.selectedIndex = randomNumber;        
        SetPalette(event)
        return
    }
    
})
</script>
"@

$HTML = @"
<script>
$JavaScript
</script>
$PaletteSelector
"@

$HTML