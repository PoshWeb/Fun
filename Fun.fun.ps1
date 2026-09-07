#requires -Module Fun

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

### Static Fun

Static sites don't have to be set in stone.

We can make static sites in fun simply by naming functions with an extension.
$(. /_includes/HighlightScript {function /index.html {
    $message = 'This is a website', 'Hello World' | Get-Random    
    "<h1>$message</h1>"
}})

To "build" our page, we can run our function and redirect the output

$(. /_includes/HighlightScript {/index.html > ./index.html})

To learn more, see [Fun Websites](/fun/website)

### Fun Fun

Fun's website is built in Fun.

The source code is in [`/Fun.fun.ps1`](/Fun.fun.ps1)

For example, the [current request](/) is handled by the function `/`:
"@
)

@(
$markdown -join [Environment]::NewLine | 
    ConvertFrom-Markdown | 
        Select-Object -ExpandProperty html

"<details><summary>function /</summary>"
. /_includes/HighlightScript (
    [ScriptBlock]::Create(
        ("function / {", 
            $myInvocation.MyCommand.ScriptBlock, 
                "}" -join [Environment]::NewLine)
    )
)
"</details>"

"<p><a href='/fun/website/source'>View Website Source</a>"

"<h3>How Fun Works</h3>"

# Functions can contain functions and filters
# These can let us write content using simple object pipelines
filter p { "<p>$_$args<p>" }

@(
    "Fun is defined in a single PowerShell script with no dependencies"

    "It outputs an object that serves functions and aliases named <code>*/*</code>"

    "It is cross-platform and works out of the box in PowerShell Core"

    "When we run the script, we return a server object.  This is used to route functions and keep server state"
    
    "We can run this script with the argument <code>start</code> to start our server"

    "Or we can <code>(./Fun.ps1).Start()</code> our server"

    "When requests come in, we route them.  We find the right function and call it"
) | p

"<details><summary>Fun.ps1</summary>"

$funScript =
    $ExecutionContext.SessionState.InvokeCommand.GetCommand(
        'Fun','Function'
    ).ScriptBlock
. /_includes/HighlightScript $funScript

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
"</details>"
)
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
    )
}

Set-Alias /index.html /

function /fun/state {
 
    param()

    "<h1>Fun State</h1>"
    "<p>Fun functions are run in their original context.  This can be very fun.</p>"
}

function /fun/website {
    $title = 'Fun Websites'

    filter p { "<p>$_$args</p>" }
    @(

    "<h1>"
    "Fun Websites"
    "</h1>"
    "<h2>"
    "Static Websites with Fun"
    "</h2>"

    p "In a dynamic site, we run our functions on demand"
    
    p "To make a static site, we can just run our functions save their output to a file"    

    /_includes/HighlightScript {/ > ./index.html}
        
    p "To make this easier, fun includes two methods: <code>.Build()</code> and <code>.Deploy()</code>"    

    p "Build runs every function named <code>*.*</code>, and gives you their output as text"    

    /_includes/HighlightScript {
        # Fun .Build()
        (fun).Build()
    }

    p "Since <code>Build</code> is an approved verb, we can also"

    /_includes/HighlightScript {
        # Build-Fun
        Build-Fun
    }

    p "We can also <code>.Deploy()</code> a build."

    p "This will run the <code>.Build()</code> and write all the files to disk, beneath the current directory."

    p "This will <code>Deploy</code> the content as a static site"

    /_includes/HighlightScript {
        # Deploy-Fun will build and deploy any *.* file.
        # Existing files will be overwritten.
        Deploy-Fun
    }
    
    )
}

function /fun/experiment {
    "<h1>Fun Experiment</h1>",
    "<h3>Fun is an experiment</h3>",
    "<p>Fun is a fun server, and it is experimental and subject to change</p>"
}

function /fun/website/source {
    $title = "Fun Website Source Code"
    "<h1>$title</h1>"
    . /_includes/HighlightScript $site.Define
}

function /fun/website/code {
    [OutputType('text/plain')]
    param()
    "$($site.Define)"
}

Set-Alias /fun/website.ps1 /fun/website/code

# We can turn a number of files into endpoints
# First up is the easy case of `*.*.ps1` files
foreach ($fileToMount in 
    Get-ChildItem -Recurse -File -Filter *.*.ps1 -Path $PSScriptRoot) {

    # Skip any *.*.ps1 that does not have a web-friendly implied extension.
    if ($fileToMount.Name -notmatch '\.(?>html|css|json|js|svg)\.ps1$') {
        continue
    }
    
    # Get the relative path
    $relativePath =
        $fileToMount.FullName.Substring($PSScriptRoot.Length) -replace 
            '\.ps1$' -replace '[\\/]','/'    

    # Set an alias from our relative path to our file    
    Set-Alias $relativePath $fileToMount.FullName

    # If the file was an index, also mount to the base path
    if ($relativePath -match '/index[^/]+$') {
        Set-Alias ($relativePath -replace '/index[^/]+$') $fileToMount.FullName
    }
}

Set-Alias /main.css /Fun.css

# Next up are Markdown files
foreach ($markdownFile in
    Get-ChildItem -Path $PSScriptRoot -Filter *.md  -File -Recurse) {
    
    # We _could_ create a function that reads the markdown
    # But it will be faster to create a function that has already read the markdown. 

    # Convert the contents from markdown
    $markdown = Get-Content $markdownFile.FullName -Raw |
        ConvertFrom-Markdown

    # and determine the right relative path
    $relativeName = $markdownFile.FullName.Substring(
        $PSScriptRoot.Length
    ) -replace '\.md$' -replace '[\\/]', '/'

    # and the name of the markdown
    $markdownName = $markdownFile.Name -replace '\.md$'

    # Our function name is our relative path
    $functionName = "$relativeName"

    # We will use the function provider to create the function
    # so we need to predetermine the function name.
    $functionPath = "function:/$functionName"

    # And then magically create a script
    $scriptLines = @(
        # Set a title
        "`$title = '$($markdownName -replace
            '-','\s' -replace
            "'","''"
        )'"
        # embed the html and pass it to layout
        "'$($markdown.Html -replace "'","''")'"
    )

    # Create the function
    $ExecutionContext.SessionState.PSVariable.Set(
        $functionPath,
        ($scriptLines -join [Environment]::NewLine)
    )
    # and set an /index.html alias
    Set-Alias "$functionName/index.html" $functionName
}
function /get/fun.ps1 {
    [OutputType('text/x-powershell')]
    param()
    Get-Command Get-Fun | 
        Select-Object -ExpandProperty ScriptBlock
}

function /404 {
    @(
        "<h1>404</h1>"
        "<h2><img src='https://media1.tenor.com/m/_OXEOGoxedQAAAAC/hal9000-hal.gif' /></h2>"
    )
}

Set-Alias /404.html /404

Fun -Parameter @{
    PaletteName = 'AdventureTime', 'Andromeda', 'Konsolas', 'Popping-and-Locking', 'Wez' | Get-Random
    AnalyticsId = 'G-HLWZJJGDCP'
    Layout = $ExecutionContext.SessionState.InvokeCommand.GetCommand('layout','Alias').ResolvedCommand.ScriptBlock
} @args

# $fun
# $fun = 1..10 | ./fun.ps1 some fun args
# $fun.Start(3)