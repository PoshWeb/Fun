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
$animationLoop = "repeatCount='indefinite'"
    $centered = "cx='50%'", "cy='50%'"

"<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 200 200' width='100%' height='100%'>"
    $psChevron

    $sequence = 42, 23, 16, 15, 8, 4
    $primes = 5, 7, 11, 13, 17, 19, 23
    for ($index = 0; $index -lt ($sequence.Length - 1); $index++) {

        $n = $sequence[$index]        
        $duration = "dur='$($primes[$primes.Length - 1 - $index])s'"
        if (-not $index) {
            "<circle $centered $transparentFill $stroke r='$n%' />"
        }
        else {
            if ($variant -match 'animate') {
                $values = " values='$(
                if ($index -eq 1) {                    
                    "$n%", "$($sequence[0])%", "$n%" -join ';'
                } else {                    
                    "$n%", "$($sequence[0])%", "$n%" -join ';'
                })'"
            }

            $opacity = 1 - (.2 * $index)
                        
            "<ellipse $centered $transparentFill $stroke rx='$n%' ry='42%' opacity='$opacity'>"
            if ($variant -match 'animate') {
                
                "<animate attributeName='rx' $animationLoop $duration $values />"
                "<animate attributeName='opacity' $animationLoop $duration values='$(
                    $opacity,($opacity/2),$opacity -join ';'
                )' />"
            }
            "</ellipse>"
            "<ellipse $centered $transparentFill $stroke rx='42%' ry='$n%' opacity='$opacity'>"
            if ($variant -match 'animate') {
                "<animate attributeName='ry' $animationLoop $duration $values />"
            }
            if ($variant -match 'animate') {
                "<animate attributeName='opacity' $animationLoop $duration values='$(
                    $opacity,($opacity/2),$opacity -join ';'
                )' />"
            }
            "</ellipse>"
        }
        if ($First -and ($index + 1) -gt $First) {
            break
        }
    }    
    "<use href='#psChevron' y='42%' height='16%' fill='#4488ff' class='foreground-fill' />"
"</svg>"
