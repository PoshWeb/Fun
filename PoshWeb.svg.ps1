param(
[string]
$Variant = '',

[int[]]
$Sequence,

[int]
$First
)

$psChevron = '<symbol id="psChevron" viewBox="0 0 100 100">
    <polygon points="40,20 45,20 60,50 35,80 32.5,80 55,50"/>
</symbol>'

$stroke = @(
    "stroke='#4488ff'"
    "class='foreground-stroke'"
    "stroke-width='0.5%'"
)
$transparentFill = "fill='transparent'"
$animationLoop = "dur='4.2s'", "repeatCount='indefinite'"
    $centered = "cx='50%'", "cy='50%'"

"<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 200 200' width='100%' height='100%'>"
    $psChevron

    $sequence = 42, 23, 16, 15, 8, 4
    for ($index = 0; $index -lt ($sequence.Length - 1); $index++) {
        $n = $sequence[$index]
        $nextN = $sequence[$index + 1]
        if (-not $index) {
            "<circle $centered $transparentFill $stroke r='$n%' />"
        }
        else {
            if ($variant -match 'animate') {
                $values = " values='$(
                if ($index -eq 1) {
                    "$n%", "$nextN%", "$n%" -join ';'
                } else {
                    "$n%", "$($sequence[$index - 1])%", "$n%" -join ';'
                })'"
            }
                        
            "<ellipse $centered $transparentFill $stroke rx='$n%' ry='42%' opacity='$(1 - (.2 * $index))'>"            
            if ($variant -match 'animate') {
                "<animate attributeName='rx' $animationLoop $values />"
            }
            "</ellipse>"
            "<ellipse $centered $transparentFill $stroke rx='42%' ry='$n%' opacity='$(1 - (.2 * $index))'>"
            if ($variant -match 'animate') {
                "<animate attributeName='ry' $animationLoop $values />"
            }
            "</ellipse>"
        }
        if ($First -and ($index + 1) -gt $First) {
            break
        }
    }    
    "<use href='#psChevron' y='29%' height='42%' fill='#4488ff' class='foreground-fill' />"
"</svg>"
