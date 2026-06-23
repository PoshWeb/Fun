
# Fun Website
if (-not $ExecutionContext.SessionState.InvokeCommand.GetCommand('layout', 'Alias')) {
    function Layout {
        @(
        "<html>"    
            "<head>"
                '<meta charset="utf-8">'
                "<title>$([Web.HttpUtility]::HtmlEncode("$title"))</title>"
                "<style>"
                    
                    "body { max-width:80vw; height: 100vh; margin-left: auto; margin-right: auto; }"

                    "h1 { text-align: center }"

                    "h2 { text-align: center }"

                "</style>"
            "</head>"
            "<body>"
                $args -join "`n"
                $input -join "`n"
            "</body>"
        "</html>"
        ) -join "`n"
    }
}

if ($PSScriptRoot) {
    $layoutPath = Join-Path $PSScriptRoot layout.ps1
    if (Test-Path $layoutPath) {
        Set-Alias Layout $layoutPath
    }
}

$includesPath = Join-Path $PSScriptRoot _includes

foreach ($include in Get-ChildItem -Path $includesPath -Filter *.ps1) {
    Set-Alias "/_includes/$($include.Name -replace '\.ps1$')" $include.FullName
}

function / {
<#
.SYNOPSIS
    Fun Server
.DESCRIPTION
    A Fun PowerShell Server
#>
[OutputType('text/html')]
param()

$funModule = Get-Module Fun
$title = "Fun Server $($funModule | Select-Object -ExpandProperty Version)"

$markdown = @(
@"
# $($funModule.Name)
## $($funModule.Description)

Fun is a fun functional server, written in PowerShell.

Any function named with `/` is a server function.

This makes servers incredibly simple.

_Your function is your server_.

Let's write Hello World:

$(. /_includes/HighlightScript {function / {"Hello World"}})

If we wanted to return a different content type, we can use the `[OutputType]` attribute.

$(. /_includes/HighlightScript {function / {
[OutputType("text/plain")]
param()
"Hello World"
}})

This approach makes PowerShell web development simple and fun.

We can use Fun to make static and dynamic websites.

For example, the [current request](/) is handled by:
"@
    
)


@(

$markdown -join [Environment]::NewLine | 
    ConvertFrom-Markdown | 
    Select-Object -ExpandProperty html

$(. /_includes/HighlightScript $myInvocation.MyCommand.ScriptBlock)

"<p>Fun is defined in a single PowerShell script:</p>"

"
<details>
<summary>Fun.ps1</summary>"
$funScript =
    $ExecutionContext.SessionState.InvokeCommand.GetCommand(
        'Fun','Function'
    ).ScriptBlock
. /_includes/HighlightScript $funScript
"</details>"

"<p>Fun.ps1 is currently:</p>"

"<ul>"
    "<li>"
        @(
            $funScript -split '(?>\r\n|\n)'
        ).Length, 'lines' -join ' '
    "</li>"
    "<li>~"
        [Math]::Round("$funScript".Length / 1kb)
    "kb</li>"
    "<li>"
    $FunScriptTokens = [Management.Automation.PSParser]::Tokenize($funScript, [ref]$null)
        $total = 0
        $docTotal = 0
        foreach ($token in $FunScriptTokens) {
            if ($token.Type -eq 'Comment') {
                $docTotal+=$token.Length
            }
            $total+=$token.Length
        }
        "{0:P2} comments" -f $($docTotal/$total)
    "</li>"
    "<li>"    
        "{0:P2} whitespace" -f (
            ($funScript -replace '\S').Length /
            $("$funScript".Length)
        )
    "</li>"
"</ul>"    
) | . Layout
}

function /get/command {
    $title = "Fun Commands"
    @(
    "<h1>$title</h1>"    
    "<ul>"
    "<li>Functions</li>"
    "<ul>"
    foreach ($func in Get-Command /* -CommandType Function) {
        "<li><a href='$($func.Name)'>$([Web.HttpUtility]::HtmlEncode($func.Name))</a></li>"
    }
    "</ul>"
    "<li>Aliases</li>"
    "<ul>"
    foreach ($func in Get-Command /* -CommandType Alias) {
        "<li><a href='$($func.Name)'>$([Web.HttpUtility]::HtmlEncode($func.Name))</a></li>"
    }
    "</ul>"
    "</ul>"
    ) | . Layout
}

Set-Alias /index.html /

function /fun/state {
 
    param()

    "<h1>Fun State</h1>"
    "<p>Fun functions are run in their original context.  This can be very fun.</p>"
}

function /fun/website {
    $title = 'Fun Websites'
    @(    

    "<h1>"
    "Fun Websites"
    "</h1>"
    "<h2>"
    "Static Websites with Fun"
    "</h2>"

    "<p>"
    "In a dynamic site, we run our functions on demand"    
    "</p>"

    "<p>"
    "To make a static site, we can just run our fun once and save it to a file"
    "</p>"

    /_includes/HighlightScript {/ > ./index.html}
        
    "<p>"
    "To make this easier, fun includes a <pre>.Build()</pre> method"
    "</p>"

    "<pre>"
        "<code class='language-powershell'>"
            [Web.HttpUtility]::HtmlEncode("(fun).Build()")
        "</code>"
    "</pre>"
    ) | . Layout
}

function /fun/experiment {
    "<h1>Fun Experiment</h1>",
    "<h3>Fun is an experiment</h3>",
    "<p>Fun is a fun server, and it is experimental and subject to change</p>" |
        . Layout
}

function /security {
    "$((ConvertFrom-Markdown -LiteralPath (
        Get-Module Fun | Split-Path | Join-Path -ChildPath "security.md" 
    )).Html)" | . Layout
}

Set-Alias /security/index.html /security

function /contributing {
    "$((ConvertFrom-Markdown -LiteralPath (
        Get-Module Fun | Split-Path | Join-Path -ChildPath "contributing.md" 
    )).Html)"|
    . Layout
}

Set-Alias /contributing/index.html /contributing

function /code-of-conduct {
    ConvertFrom-Markdown -LiteralPath (
        Get-Module Fun | Split-Path | Join-Path -ChildPath "code_of_conduct.md"
    ) |
    Select-Object -ExpandProperty Html |
    . Layout
}

Set-Alias /code-of-conduct/index.html /code-of-conduct
function /get/fun {
    [OutputType('text/plain')]
    param()
    Get-Command Get-Fun | 
        Select-Object -ExpandProperty ScriptBlock
}

Set-Alias /get/fun.ps1 /get/fun
function /404 {
    @(
        "<h1>404</h1>"
        "<h2><img src='https://media1.tenor.com/m/_OXEOGoxedQAAAAC/hal9000-hal.gif' /></h2>"
    ) | . Layout
}

Set-Alias /404.html /404


# $fun
# $fun = 1..10 | ./fun.ps1 some fun args
# $fun.Start(3)