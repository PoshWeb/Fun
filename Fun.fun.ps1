
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

function / {
<#
.SYNOPSIS
    Fun Server
.DESCRIPTION
    A Fun PowerShell Server
#>
[OutputType('text/html')]
param()

$title = "Fun Server $(Get-Module Fun | Select-Object -ExpandProperty Version)"

@"

<h1>Fun</h1>

<h2>A Fun PowerShell Server</h2>

<p>
Fun is a fun functional interactive PowerShell server.
</p>

<p>
It maps a url to a PowerShell function.
</p>

<p>
For example, the current request to <a href='$(
    $request.url.LocalPath
)'>$(
    $request.Url.LocalPath
)</a> is handled by:
</p>

<pre>
    <code class='language-powershell'>
$([Web.HttpUtility]::HtmlEncode($MyInvocation.MyCommand.ScriptBlock))
    </code>
</pre>

<p>
Fun is defined in a single PowerShell script:
</p>

<details>

    <summary>Fun.ps1</summary>

        <pre>

            <code class='language-powershell'>
$([Web.HttpUtility]::HtmlEncode(
    $ExecutionContext.SessionState.InvokeCommand.GetCommand('Fun','Function').ScriptBlock    
))
            </code>

        </pre>
</details>
"@ | . Layout
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
    ) | Layout
}

Set-Alias /index.html /

function /fun/state {
 
    param()

    "<h1>Fun State</h1>"
    "<p>Fun functions are run in their original context.  This can be very fun.</p>"
}

function /fun/website {
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

    "<pre>"
    "<code class='language-powershell'>"
    [Web.HttpUtility]::HtmlEncode("/ > ./index.html")
    "</code>"
    "</pre>"
    
    "<p>"
    "To make this easier, fun includes a <pre>.Build()</pre> method"
    "</p>"

    "<pre>"
        "<code class='language-powershell'>"
            [Web.HttpUtility]::HtmlEncode("(fun).Build()")
        "</code>"
    "</pre>"
}

function /fun/experiment {
    "<h1>Fun Experiment</h1>",
    "<h3>Fun is an experiment</h3>",
    "<p>Fun is a fun server, and it is experimental and subject to change</p>" |
        Layout    
}

function /fun/security {
    "$((ConvertFrom-Markdown -LiteralPath (
        Get-Module Fun | Split-Path | Join-Path -ChildPath "security.md" 
    )).Html)" | Layout
}

Set-Alias /fun/security/index.html /fun/security

function /fun/contributing {
    "$((ConvertFrom-Markdown -LiteralPath (
        Get-Module Fun | Split-Path | Join-Path -ChildPath "contributing.md" 
    )).Html)"|
    Layout
}

Set-Alias /fun/contributing/index.html /fun/contributing

function /fun/code-of-conduct {
    ConvertFrom-Markdown -LiteralPath (
        Get-Module Fun | Split-Path | Join-Path -ChildPath "code_of_conduct.md"
    ) |
    Select-Object -ExpandProperty Html |
    Layout
}

Set-Alias /fun/code-of-conduct/index.html /fun/code-of-conduct
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
    ) | Layout
}


# $fun
# $fun = 1..10 | ./fun.ps1 some fun args
# $fun.Start(3)