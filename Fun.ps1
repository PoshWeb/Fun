<#
.SYNOPSIS
    Fun Server 
.DESCRIPTION
    A Fun Server in PowerShell.
    
    Fun makes web dev fun and interactive.

    We just write function that start with `/`.
    
    Then `Start-Fun`
    
    For example:

    ~~~PowerShell
    function / { 
        "Hello From Fun", "Hi from Fun", "It's Fun" | Get-Random
    }

    Start-Fun
    ~~~

    Fun supports live reloading of functions.
    
    We can redefine functions at any time.

    Functions run in our current context.
    
    This allows for fun interations between the browser and the terminal.    
.NOTES
    This is a fun experimental server in PowerShell.

    It is build atop a design pattern:

    Any function starting with `/` will serve request.    

    Functions can be a local path or a wildcard of the url.

    Whenever the url is visited, the funtion will be run.    

    Any query parameters will be automatically mapped to function parameters.

    You can write code with this pattern and not have `Fun`.

    `Fun` just makes it fun.

    By default, in `Fun`, functions run as the current user.
    
    They have access to the current state.

    This includes, but is not limited to:

    * Currently loaded modules
    * Current variables
    * The Current PowerShell Host
    * PowerShell Events
    
    This allows for fun and unique server scenarios.
    
    We can allow selective control over our terminal (and operating systems) from our browser.

    This is as fun (and potentially dangerous) as it sounds.

    While we can call any command as a service, we want to be selective.

    For these reasons, we want to run `Fun` locally on a random loopback port,
    or in a container with a constrained list of commands.

    We also want to avoid code injection at all costs, and only expose safe commands.
    
    Fun also allows you to redefine how it serves content and outputs results.

    You should not need to do this in most scenarios, but it can be fun to mod an engine.

    Fun can run isolated when provided an -InitializeScript file.
.EXAMPLE
    # Hello World server
    function / { "<h1>hello world</h1>" }

    Start-Fun
.EXAMPLE
    function / {
        "<h1>Hello from Fun</h1>"
        "<h2>It is $([DateTime]::Now).</h2>"
        "<h3>Here's a random number $([Random]::new().next())</h3>"
    }

    (fun).Start()
.EXAMPLE
    # Fun Website
    Get-Module Fun | 
        Split-Path | 
        Push-Location
    . ./Fun.fun.ps1

    Start-Fun

    Pop-Location
#>
[CmdletBinding(PositionalBinding=$false)]
[Alias('Start-Fun','Deploy-Fun','Build-Fun')]
param(
# A list of any arguments.
# If an argument starts with `https?://`, 
# it will be considered a prefix.
# If the argument is 'start', it will start the server.
# All arguments will be persisted and added to the output object.
# This allows them to be used inside of a server, via `$this.Arguments`
[Parameter(ValueFromRemainingArguments)]
[Alias('Arguments','Argument','Args')]
[PSObject[]]
$ArgumentList,

# Any Input Object.
# This is currently passed on directly to a server instance.
# Any function can reference this input with `$this.Input`
[Parameter(ValueFromPipeline)]
[Alias('Input')]
[PSObject]
$InputObject,

# If set, will not allow websocket requests.
# Requests to websockets will return 405 - Method Not Allowed.
[switch]
$NoWebSocket,

# If set, will stream responses.
# This will stream output from running commands
[switch]
$Stream,

# The size of websocket buffers.
# This is the maximum size of a message sent to a websocket.
[uint32]
$BufferSize = 64kb,

# The depth used to serialize websocket responses to json.
[ValidateRange(1,100)]
[byte]
$JsonDepth = 5,

# Any site wide parameters or metadata.
# If any keys match parameter names, will attempt to set the parameter.
[Alias('Parameters','Metadata')]
[Collections.IDictionary]
$Parameter,

# The Script Block used to route requests
# This accepts a url as the first argument,
# and all other arguments as functions.
# It should return the function that best matches the url.
[ScriptBlock]
$Router = {
    param()
    $url, $functions = $args
    if (-not $url) { return }
    # We can have one of three possible names
    
    $exactNames = @(
        # Fully qualified (i.e `function http://127.0.0.1/ {}` )
        $url.Scheme,'://',
            $url.DnsSafeHost,
                $url.LocalPath -join ''
        # Host qualified (i.e `function example.com/ {}` )
        $url.DnsSafeHost,
            $url.LocalPath -join ''
        # Scheme qualified (i.e. `function http:// {}` ) 
        $url.Scheme,':/',
            $url.LocalPath -join ''
        # Locally qualified (i.e. `function / {} ) 
        $url.LocalPath
    )
    
    $localPath = $url.LocalPath

    [Array]::Reverse($functions)

    $exactMatches = # Simply -match the function to the exact names
        @(@($functions) -match "^(?>$(
            @(foreach ($exactName in $exactNames) {
                [Regex]::Escape($exactName)
            }) -join '|'
        ))/?$")

    return @(
        if ($exactMatches) {
            $exactMatches[0]
        } else {
            foreach ($function in $functions) {
                # We don't want to be too picky about ending slashes,
                # so remove them from our function name.
                $functionWildcard = $function.Name -replace
                    '/$' -replace
                    '/[\:\$][^/]+','/?*'
                if (
                    # If the local path is like our function name
                    $localPath -and (
                        # we've found our function
                        $localPath -replace '/$' -like $functionWildcard
                    )
                ) {
                    # Break after the first function we find.
                    $function
                    break
                }
            }
        }
    )
},

[ScriptBlock]
$GetFunctionFormData = {
    param([uri]$url, [string]$body, [string]$contentType)

    $formData = [Ordered]@{}
    if ($Url.Query) {    
        $parsedQueryString = [Web.HttpUtility]::ParseQueryString($Url.Query)
        # Then copy over our parameters.
        foreach ($queryParameter in $parsedQueryString.Keys) {
            if (-not $queryParameter) { continue }
            $formData[$queryParameter] = $parsedQueryString[$queryParameter]
            if ($formData[$queryParameter] -match '^(true|false)$') {
                $formData[$queryParameter] = $formData[$queryParameter] -match '^true'
            }
        }
    }

    # If the content type is urlencoded and we have a body
    if ($ContentType -eq 'application/x-www-form-urlencoded' -and $body) {
        # Read the input
        $parsedQueryString = [Web.HttpUtility]::ParseQueryString($Body)
        foreach ($queryParameter in $parsedQueryString.Keys) {
            if (-not $queryParameter) { continue }
            $formData[$queryParameter] = $parsedQueryString[$queryParameter]
            if ($formData[$queryParameter] -match '^(true|false)$') {
                $formData[$queryParameter] = $formData[$queryParameter] -match '^true'
            }
        }
    }
    
    return $formData
},

[Alias('GetFunctionArguments','GetFunctionArgs')]
[ScriptBlock]
$GetFunctionPathParameter = {
    <#
    .SYNOPSIS
        Gets parameters from the path
    .DESCRIPTION
        Gets function parameters from the path segments.
    #>
    param(
    [Parameter(Mandatory)]$Function,
    [Parameter(Mandatory)][uri]$Url
    )
    
    # Break the name into segments after we
    $nameSegments = @(
        $function.Name -replace
            # remove http and ws protocols
            '^(?>http|ws)s?://' -replace
                # replace any `*.*` before a slash
                '^[^\.]+\..+/' -split 
                    # and split them just after every / or the end
                    '(?<=(?>/|$))'
    )

    # If we want verbose information, trace out the name and url segments    
    if ($VerbosePreference -notin 'Ignore','SilentlyContinue') {
        Write-Verbose "$($NameSegments -join "`t")"
        Write-Verbose "$($url.Segments -join "`t")"
    }
    
    $PathParameters = [Ordered]@{
        Function = $Function
        Url = $Url
        BoundParameters = [Ordered]@{}        
    }

    $PathParameters.UnboundArguments = @(
        # To get arguments, we need to go thru each segment in the name    
        for ($nSegment = 0; $nSegment -lt $nameSegments.Length; $nSegment++) {
            # and (potentially) map it to the corresponding request segment.
            $requestSegment =
                if ($nSegment -le $url.Segments.Count) {
                    $Url.Segments[$nSegment]
                } else {
                    # If we are out of actual request segments, break
                    break 
                }
            
            $nameSegment = $nameSegments[$nSegment]

            $requestSegment = $requestSegment -replace '/'

            # If the name segment is a variable
            if ($nameSegment -match '^[\:\$]') {
                # it should be a parameter name.
                $parameterName = $nameSegment -replace '^[\:\$]'                
                # and we should map the segment by name.
                $PathParameters.BoundParameters[$parameterName] = $requestSegment                
            }

            # If the segment is a wildcard, we will map the segment positionally
            if ($nameSegment -match '^\*/?$') { $requestSegment }
        }

        $nSegment--

        if ($nSegment -lt $url.Segments.Length) {
            $range = $nSegment..($url.Segments.Length - 1)
            foreach ($segment in $Url.Segments[$range]) {
                $segment -replace '/'
            }
        }
    )
    return $PathParameters
}, 

[ScriptBlock]
$GetFunctionQueryParameter = {
    param($url)
    
},

# Initialization scripts
# Providing initialization scripts will isolate the server.
# This should not expose any functions not defined in the initialization scripts.
# Any required modules should be imported.
[Alias('Init','IsolateScript')]
[ValidateScript({
    if ($_ -isnot [ScriptBlock] -and 
        $_ -isnot [Management.Automation.ExternalScriptInfo] -and 
        -not ($_ -match '\.ps1$' -and (Test-Path $_))
    ) {
        throw "Must be ScriptBlock or External Script"
    }
    return $true
})]
[PSObject[]]
$InitializeScript,

# A script block used to output http requests.
[ScriptBlock]
$HttpOutput = {
    $allOutput = @($input)
    $allOutputBytes = $allOutput -as [byte[]]
    if (-not $allOutputBytes) {
        # with a buffer holding all the output
        $allOutputBytes = $encoding.GetBytes((@(
            foreach ($in in $allOutput) {
                $inXml = $in.OuterXml
                if ($inXml) {"$inXml"}
                elseif ($($inHtml = $in.html;$inHtml)) {"$inHtml"}
                elseif ($in.ToString.Invoke) {$in.ToString()}
            }
        ) -join ''))
    }
    # CGI requests just need to close
    $response.Close(
        $allOutputBytes,$false
    )
},

# A script block used to stream http outputs.
# This will be used when `-Streaming` output. 
[ScriptBlock]
$HttpStreamOutput = {
    # If we are streaming a CGI request
    begin {
        # We need to set the protocol version
        $response.ProtocolVersion = '1.1'
        # and send chunked responses.
        $response.SendChunked = $true
        $outputStream = $response.OutputStream
    }
    process {
        # Then we output each object
        $in = $_
        if ($outputStream.CanWrite) {
            $outBytes = $in -as [byte[]]
            $buffer = if ($outBytes) {
                $outBytes
            } else {
                $encoding.GetBytes(
                    $(
                        $inXml = $in.OuterXml
                        if ($inXml) {"$inXml"}
                        elseif (
                            $($inHtml = $in.html;$inHtml)
                        ) {"$inHtml"}
                        elseif ($in.ToString.Invoke) {
                            $in.ToString()
                        }                        
                    )
                )
            }
            
            $outputStream.Write($buffer, 0, $buffer.Length)
            $outputStream.Flush()
        } else {
            # If there was no output stream, emit the result.
            $in
        }
    }
    end {
        # Close our response when the command is done
        if ($response.Close) {$response.Close()}
    }
},

# The server script.
# This should listen for requests and `.Run` with that context.
[ScriptBlock]
$ServerScript = {
    param($server, [Collections.IDictionary]$IO = [Ordered]@{})
    # It will have a listener
    $httpListener = $server.HttpListener
    
    foreach ($key in @($IO.Keys)) {
        $ExecutionContext.SessionState.PSVariable.set($key, $IO[$key])
    }

    if ($server.Initialize) {
        $server.Functions = 
            $ExecutionContext.SessionState.InvokeCommand.GetCommands('*/*','Function,Alias', $true)
    }
    
    # and we can loop while it is listening
    if (-not $server.Counter) {            
        $server | Add-Member NoteProperty Counter ([long]0) -Force
    }
    
    :nextRequest while ($httpListener.IsListening) {
        # Get the next context
        $getContext = $httpListener.GetContextAsync()
        # and wait until it's ready
        while (-not $getContext.Wait(11)) { }
        $context = $getContext.Result        
        # Run our function
        # If we don't yet have a counter, create one.
        $request, $response = $context.Request, $context.Response
        
        # Increment our counter
        $server.Counter++

        try {
            $server.Run($context)
        } catch {
            $err = $_
            $response.StatusCode = 400
            $response.ContentType = 'text/plain'
            $response.Close([Text.Encoding]::UTF8.GetBytes(
                "$err$(
                    if ($err.Exception.InnerException) { [Environment]::Newline; $err.Exception.InnerException}
                    $err | Select-Object * | Out-String
                )"
            ), $false)
            $err
        }        
    }
},

# The Socket Job.
# This will run whenever a new socket is created.
# It should listen to results from that socket and output them
# It should run any functions associated with the socket and reply with their output.
[ScriptBlock]
$SocketJob = {
    param($this, $socketInfo)
    $webSocket = $socketInfo.WebSocket
    $context = $socketInfo.Context
    $request, $response = $context.Request, $context.Response
    # If we had an initialization script,
    # Locally scope our functions.
    if ($this.InitializationScript) {
        $this.Functions =
            $ExecutionContext.SessionState.InvokeCommand.GetCommands(
                '*/*','Function,Alias', $true
            )
    }

    $url = $Request.Url
    
    # This loop will run as long as the websocket is open.
    :WebSocketMessageLoop while ($websocket.State -eq 'Open') {
        # Websockets fill a buffer of memory        
        $Buffer = [byte[]]::new($this.BufferSize)        
        # Get a segment containing our buffer
        $Segment = [ArraySegment[byte]]::new($Buffer)
        # and await the next message.
        $receivingWebSocket = $webSocket.ReceiveAsync(
            $Segment, [Threading.CancellationToken]::None
        )
        
        # use this tight loop to let us cancel the await if we need to.
        while (-not $receivingWebSocket.Wait(11)) {}
        
        # If we had a problem, write an error.
        if ($receivingWebSocket.Exception) {
            Write-Error -Exception (
                $receivingWebSocket.Exception
            ) -Category ProtocolError
            continue
        }
        
        # At this point we should have a json message, in UTF8
        $encoding = [Text.Encoding]::UTF8        
        try {                
            # WebSocket buffers are "old school" null terminated strings
            # So let's find the null terminator (the first 0)
            $nullTerminator = $Buffer.IndexOf([byte]0)
            # and let's get the message.
            $messageString = if ($nullTerminator -ge 0) {
                $encoding.GetString($Buffer, 0, $nullTerminator)
            } else {
                $encoding.GetString($Buffer, 0, $Buffer.Length)
            }
            
            # Now let's convert it from json
            $socketMessage =
                if ($messageString) {
                    try {
                        ConvertFrom-Json -InputObject $messageString
                    } catch {
                        # if we could not, treat it as plain text.
                        "$messageString"
                    }
                } else { $null }
            
            if ($socketMessage) {
                $this.Run($socketInfo, $socketMessage)
            } else {
                $this.Run($socketInfo)
            }
        } catch {
            Write-Error $_
        }
    }
},

# The WebSocket Output.
# This will be called to output a result to a websocket.
[ScriptBlock]
$WebSocketOutput = {
    $out = @($input) # Websockets just need to take all output
    if ($out.Length -eq 1) { $out = $out[0] }
    # and send it down the wire as json
    $webSocket.SendAsync(
        [ArraySegment[byte]]::new($encoding.GetBytes(
            (ConvertTo-Json -InputObject $out -Depth $JsonDepth)
        )
    ), 'Text', $true, [Threading.CancellationToken]::None)
},

# The WebSocket streaming output.
# This will be called to output a series of results to a websocket.
[ScriptBlock]
$WebSocketStreamOutput = {
    process {
        $out = @($_) # take each output
        if ($out.Length -eq 1) { $out = $out[0] }
        # and send it directly along to the socket.
        $webSocket.SendAsync(
            [ArraySegment[byte]]::new($encoding.GetBytes(
                (ConvertTo-Json -InputObject $out -Depth $JsonDepth)
            )
        ), 'Text', $true, [Threading.CancellationToken]::None)
    }
}
)

# This function is designed to be pretty performant,
# so we want to handle all of our input once it has been piped in.
$allInput = @($input)
# (we also want to accept non-piped input)
if (-not $allInput -and $InputObject) {
    $allInput = @($InputObject)
}

# We will be outputting a custom object named after ourself
$myTypeName =
    $MyInvocation.MyCommand.Name -replace
        '\.ps1$' -replace '^.+?-' # (replacing the extension and any verb)

Update-TypeData -TypeName $myTypeName -Force -DefaultDisplayPropertySet (
    'CreatedAt','Prefix','Functions'
)

# Create a dictionary for our output object
$output = [Ordered]@{PSTypeName = $myTypeName}

# Handle any defined `-Parameter`
$myParameters = $MyInvocation.MyCommand.Parameters
if ($Parameter.Count) {
    foreach ($parameterName in $Parameter.Keys) {
        # If the parameterName is one of this commands parameters
        if ($myParameters[$parameterName]) {
            # Try to bind the value
            $ExecutionContext.SessionState.PSVariable.Set(
                $parameterName, $Parameter[$parameterName])
        } else {
            # Otherwise, set the key
            $output[$parameterName] = $Parameter[$parameterName]
        }
    }
}

# Bind all of our existing parameters
foreach ($key in $myParameters.Keys) {
    $var = $ExecutionContext.SessionState.PSVariable.get($key)
    if ($var) { $output[$key] = $var.Value }
}

# Hard code a small number of fields:
$output.CreatedAt  = [DateTime]::Now # * `.CreatedAt`
$output.Functions  = $ExecutionContext.SessionState.InvokeCommand.GetCommands(
    '*/*','Function,Alias', $true
) # * `.Functions`
$output.Arguments  = $ArgumentList # * `.Arguments`
$output.Input      = $allInput # * `.Input`

# Create our object and extend it
$outputObject = New-Object PSObject -Property $output |
    #region `.Build()`
    Add-Member ScriptMethod Build {
        <#
        .SYNOPSIS
            Builds the server 
        .DESCRIPTION
            Builds the server into a static site.
        
            Will build any `/` function whose name is like *.*
            
            Output a list of paths and the contents of the files. 
        #>
        param()
        $this.Functions |
            . { process {
                $cmd = $_

                if ($cmd.Name -notlike '*.*') { return }
                if ($cmd.Name -match '\*') { return }

                try {$output = . $cmd} 
                catch {
                    Write-Warning "Error building $($cmd.Name): $_ "
                    return
                }

                [Ordered]@{
                    Path = "./$($cmd.Name -replace "^/")"
                    Value= if ($output -as [byte[]]) {
                        $output -as [byte[]]
                    } else {
                        $output -join [Environment]::NewLine
                    }
                }
            } }
    } -Force -PassThru |
    #endregion `.Build`
       
    #region `.Clear`
    Add-Member ScriptMethod Clear {
        foreach ($func in $this.Functions) {
            try {
                if ($func -is [Management.Automation.FunctionInfo]) {
                    Remove-Item "function:/$(
                        $func.Name -replace  '\*','`*' -replace '\?', '`?'
                    )"
                } elseif ($func -is [Management.Automation.AliasInfo]) {
                    Remove-Item "alias:/$(
                        $func.Name -replace  '\*','`*' -replace '\?', '`?'
                    )"
                }
            } catch {
                Write-Warning "Could not remove $($func.Name) - $_"
            }
        }
    } -Force -PassThru |
    #endregion `.Clear`
    #region `.Define`
    Add-Member ScriptProperty Define {
        <#
        .SYNOPSIS
            Define the Current endpoints.
        .DESCRIPTION
            Returns a script that will define of all current endpoints.
        #>        
        [ScriptBlock]::Create(
            @(
                foreach ($func in $this.Functions) {
                    if ($func -is [Management.Automation.FunctionInfo]) {
                        "function $func {$(
                            $func.ScriptBlock
                        )$([Environment]::NewLine)}"
                    } elseif ($func -is [Management.Automation.AliasInfo]) {
                        "Set-Alias '$(
                            $func.Name -replace "'","''"
                        )' '$(
                            $func.ResolvedCommand -replace "'","''"
                        )'"
                    }
                }
            ) -join [Environment]::NewLine
        )
    } -Force -PassThru |
    #endregion `.Define`
    #region `.Deploy`
    Add-Member ScriptMethod Deploy {
        <#
        .SYNOPSIS
            Deploys the server 
        .DESCRIPTION
            Deploys the server as a static site.
        
            Will deploy any `/` function whose name is like *.*
            
            Existing files will be overwritten.
        #>
        param([string]$Path = $pwd)
        foreach ($fileBuilt in $this.Build()) {
            $fileBuilt.Path = Join-Path $path $fileBuilt.Path
            if ($fileBuilt.Value -is [byte[]]) {
                $newFile = New-Item -Path $fileBuilt -Force
                [IO.File]::WriteAllBytes($newFile.FullName, $fileBuilt.Value)
                Get-Item -LiteralPath $fileBuilt
            } else {                
                New-Item @fileBuilt -Force
            }
        }        
    } -Force -PassThru |
    #endregion `.Deploy`
    #region `.Prefix`
    Add-Member ScriptProperty Prefix {
        if ($this.HttpListener.Prefixes.Length -eq 1) {
            $this.HttpListener.Prefixes[0]
        } else {
            $this.HttpListener.Prefixes
        }
    } -Force -PassThru |
    #endregion `.Prefix`
        
    #region `.Remove`
    Add-Member ScriptMethod Remove {
        param([string]$Wildcard)
        if (-not $Wildcard) { return }
        foreach ($func in $this.Functions) {
            if ($func.Name -notlike $Wildcard) { continue }
            try {
                if ($func -is [Management.Automation.FunctionInfo]) {
                    Remove-Item "function:/$(
                        $func.Name -replace  '\*','`*' -replace '\?', '`?'
                    )"
                } elseif ($func -is [Management.Automation.AliasInfo]) {
                    Remove-Item "alias:/$(
                        $func.Name -replace  '\*','`*' -replace '\?', '`?'
                    )"
                }
            } catch {
                Write-Warning "Could not remove $($func.Name) - $_"
            }
        }
    } -Force -PassThru |
    #endregion `.Remove

    #region `.RequestRate`
    # We also want one script property that calculates a request rate
    Add-Member ScriptProperty RequestRate {
        # To do this we just take the counter
        ($this.Counter -as [long]) /
            # and divide by the number of minutes we have been running
            ([DateTime]::Now - $this.CreatedAt).TotalMinutes
    } -Force -PassThru |
    #endregion `.RequestRate`
    
    #region `.Run`
    Add-Member ScriptMethod Run {
        <#
        .SYNOPSIS
            Run in a context
        .DESCRIPTION
            Run the function in http request context or websocket context
        #>
        param(
        # The context
        $context,

        $socketMessage
        )

        # Allow for mock requests by enabling casting to uris
        if ($context -as [uri]) {
            $request = [Ordered]@{HttpMethod='Get';Url = $context -as [uri]}
        } elseif ($context.context) {
            $request, $response = $context.Context.Request, $context.Context.Response
        } else {
            $request, $response = $context.Request, $context.Response
        }

        $site = $this
        
        # WebSocket handshake requests should be specially handled before we route to a function.
        if ($Request.IsWebSocketRequest -and -not $context.WebSocket) {
            if ($site.NoWebSocket) {
                # Method not allowed
                $response.StatusCode = 405
                $response.Close()
            }
            # We need to call the `AcceptWebSocketAsync` method to upgrade the connection.
            $acceptWebSocket = $context.AcceptWebSocketAsync('json')
            # We'll .Wait until the upgrade is finished.
            while (-not $acceptWebSocket.Wait(11)) { }
            # If it fails,
            if ($acceptWebSocket.IsFaulted) {
                # we will write an error and return.
                Write-Error -Exception $acceptWebSocket.Exception -Category ProtocolError
                return
            }
            # If it succeeds, capture the result.
            $webSocketResult = try { $acceptWebSocket.Result } catch { $_ }

            # If we do not have any sockets on this object
            if (-not $site.Sockets) {
                # create a dictionary to hold them.
                $site | Add-Member NoteProperty Sockets ([Ordered]@{}) -Force
            }

            # If we do not have any sockets on this url
            if (-not $site.Sockets[$request.Url]) {
                # create a list
                $site.Sockets[$request.Url] = @()
            }
            
            # Prepare our socket info.
            # This contains the initial request as well as web socket context.
            $socketInfo = ([PSCustomObject]@{
                Context = $context
                Request = $request
                Response = $response
                WebSocket = $webSocketResult.WebSocket
                WebSocketContext = $webSocketResult
            })

            $request |
                Add-Member NoteProperty Url (                    
                    ($request.Url -replace '^http', 'ws') -as [uri]
                ) -Force
            $socketJobParams = [Ordered]@{
                Name = "$($request.Url)"
                ArgumentList = $site,$socketInfo
                ThrottleLimit = 32kb
                ScriptBlock = $site.SocketJob
            }
            if ($site.InitializationScript) {
                $socketJobParams.InitializationScript = $socketJobParams
            }
            # Each websocket runs in its own thread job
            $socketJob = Start-ThreadJob @socketJobParams |
                Add-Member NoteProperty HttpListener $site.HttpListener -Force -PassThru |
                Add-Member NoteProperty SocketInfo $socketInfo -Force -PassThru |
                Add-Member NoteProperty WebSocket $socketInfo.WebSocket -Force -PassThru |
                Add-Member NoteProperty Url $socketInfo.Request.Url -Force -PassThru |
                Add-Member NoteProperty Fun $site -Force -PassThru
            
            $urlString = "$($request.Url)"
            $site.Sockets[$urlString] += $socketJob

            # While we're here, might as well clean up finished socket jobs.
            $toRemove = @()
            $site.Sockets[$urlString] = # Make one pass thru all sockets to this url
                @(foreach ($socket in $site.Sockets[$urlString]) {
                    # If they are not completed or failed
                    if ($socket.State -notin 'Completed', 'Failed') {
                        $socket # keep it in the list
                    } else {
                        # otherwise, mark it for removal
                        $toRemove += $socket
                    }
                })

            # Remove only the jobs that completed without error.
            $toRemove | Where-Object State -ne 'Failed' | Remove-Job
            # Either way, return the socket job.
            return $socketJob
        }
        
        # * `$Method` should contain the HttpMethod
        $Method = $request.HttpMethod
        # * `$body` should contain the request body as a string
        $body = ''
        
        # We want to match the url to a function.
        $url = $request.Url

        $encoding = [Text.Encoding]::UTF8

        $headers = [Ordered]@{}
        if ($request.Headers) {
            foreach ($key in $request.Headers.Keys) {
                $headers[$key] = $request.Headers[$key]
            }
        }

        $cookies = [Ordered]@{}
        foreach ($cookie in $request.Cookies) {
            if (-not $cookie.Name) { continue }
            $Cookies[$cookie.Name] = $cookie
        }

        $webSocket = $null
        # This is only _slightly_ different for websocket requests.
        # If the request is a websocket request, and we've got a live socket
        if ($request.IsWebSocketRequest -and $context.WebSocket) {
            $webSocket = $context.WebSocket
            # and make $url reflect the new value
            $url = $request.Url
            $JsonDepth = $this.JsonDepth
        }

        # Now that URL is properly defined (websocket or not)
        # we can just `.Route` our functions.
        $functions = @(
            # (We just need to use use a new closure to avoid potential locks)
            . $this.Router.GetNewClosure() $url $this.Functions
        )

        # If there were no found functions and this isn't a websocket request
        if (-not $functions -and -not $request.IsWebSocketRequest) {
            # We're going to send a 404.
            if ($response.StatusCode) { $response.StatusCode = 404 }
            # We want that 404 to be customizable,
            # so look for a function named the status code `(i.e. /404)
            $statusCodeFunction = @($this.functions -match "^/$($response.StatusCode)/?$")
            if ($statusCodeFunction) {
                # If one existed, set `$functions` and call it normally.
                $functions = $statusCodeFunction
            } else {
                # Otherwise, close the response
                $response.Close([Text.Encoding]::UTF8.GetBytes("No Fun @ $($request.Url)"), $false)
                return
            }
        }

        # After we've routed, get the last matching function. 
        $function = $functions[-1]

        # If we have not mapped a function, return.
        if (-not $function) { return }
                
        # Http input streams can only be read once
        # and we may want to read the content twice
        # (or in two different ways)
        $memoryStream = [IO.MemoryStream]::new()
        $streamReader = $null
        
        if ($request.InputStream.CanRead) {
            $request.InputStream.CopyTo($memoryStream)
        }
        
        # If we have any input
        if ($memoryStream.Length) {
            $null = $memoryStream.Seek(0,'begin')
            $streamReader = [IO.StreamReader]::new($memoryStream)
            # read the body
            $Body = $streamReader.ReadToEnd()
            # seek back to 0 so we can read things again
            $null = $memoryStream.Seek(0,'begin')
        }

        # To add to the fun, we want our functions to take parameters
        $FormData = . $site.GetFunctionFormData.GetNewClosure() $request.Url $body $request.ContentType

        $query = [Ordered]@{} + $FormData
        
        # If the method is POST and we can read input
        if ($body -and $request.ContentType -eq 'application/json') {
            $parsedBody = ConvertFrom-Json -InputObject $body
            foreach ($property in $parsedBody.psobject.properties) {
                if (-not $property) { continue }
                $query[$property.Name] = $parsedBody.($property.Name)
            }
        }

        # Get our path parameters
        $pathParameters = @(
            . $site.GetFunctionPathParameter.GetNewClosure() $function $url
        )

        # Create a map of all potential parameter names.
        $functionParameterMap = @{}
        foreach ($parameter in @((
            $function -as [Management.Automation.CommandMetadata]
        ).Parameters.Values)) {
            # PowerShell parameters have names
            $functionParameterMap[$parameter.Name] = $parameter
            # but can also have any number of aliases.
            foreach ($alias in $parameter.Aliases) {
                $functionParameterMap[$alias] = $parameter
            }
        }
        
        # Create a collection of all function parameters
        $functionParameters = [Ordered]@{}

        # Go over every source of potential named parameters,
        foreach ($namedParameters in $FormData, $pathParameters.BoundParameters) {
            if (-not $namedParameters) { continue }
            # walk over each parameter name in the set,
            foreach ($parameterName in $namedParameters.Keys) {
                # check that it is a parameter
                $functionParameter = $functionParameterMap[$parameterName]
                if ($functionParameter) {
                    # and map the parameter to the value.
                    $functionParameters[
                        $functionParameter.Name
                    ] = $namedParameters[$parameterName]
                }
            }
        }

        # If we passed a socket message, walk over its properties
        if ($socketMessage -isnot [string] -and 
            $socketMessage -isnot [object[]]
        ) {
            foreach ($property in $socketMessage.psobject.properties) {
                # and map them to the function where we can.
                $functionParameter = $functionParameterMap[$property.Name]
                if ($functionParameter) {
                    $functionParameters[$functionParameter.Name] =
                        $socketMessage.$($property.Name)
                }
            }
        }
        

        # If the function had an output type like `*/*`
        if ($function.OutputType.Name -like '*/*' -and
            $response.OutputStream) {
            foreach ($outputType in $function.OutputType) {
                if ($outputType.Name -like '*/*') {
                    # this will become the response content type
                    $response.ContentType = $outputType.Name
                    break
                }
            }
        }

        # If we do not have an output type
        if (-not $function.OutputType) {
            # default to `text/html`
            $response.ContentType = 'text/html'
        }
        
        # We need to determine how we will handle function output.
        $FunctionOutput =
        # We do not always want to stream content
            if ($(
                # we should only stream if `$this` or the `$function` say so.
                $site.Stream
            )) {
                if ($request.IsWebSocketRequest) {
                    # If we are streaming a websocket request
                    $site.WebSocketStreamOutput
                } else {
                    $site.HttpStreamOutput
                }
            } else {
                # If we are not streaming, output is easier
                if ($request.IsWebSocketRequest) {
                    $site.WebSocketOutput
                } else {
                    $site.HttpOutput
                }
            }
        
        $functionArgs = @($pathParameters.UnboundArguments)
        $functionOutput = $functionOutput.GetNewClosure()
        # Call our function and stream the results
        try {
            # If the function had positional parameters
            if ($functionArgs) {
                # pass them first
                . $function @functionArgs @functionParameters *>&1 |
                    . $functionOutput
            } else {
                # otherwise, call our function with named parameters
                . $function @functionParameters *>&1 |
                    . $functionOutput
            }
        } catch {
            $err = $_
            $response.StatusCode = 400
            $response.ContentType = 'text/plain'
            $response.Close([Text.Encoding]::UTF8.GetBytes(
                "$($err | Out-String)"
            ), $false)
            $err
        } finally {
            if ($streamReader) {
                $streamReader.Close(),$streamReader.Dispose()
            }
            if ($memoryStream) {
                $memoryStream.Close(),$memoryStream.Dispose()
            }
        }
    } -Force -PassThru |
    #endregion `.Run`

    #region `.Start`
    Add-Member ScriptMethod Start {
        param()
        # In order to start the fun, we need an http listener
        if (-not $this.HttpListener) {
            # Attach this listener to this object
            $this | Add-Member NoteProperty HttpListener (
                [Net.HttpListener]::new()
            ) -Force
            # If we have any prefixes, add them.
            if ($this.Prefixes) {
                foreach ($prefix in $this.Prefixes) {
                    $httpPrefix = $prefix -replace '/{0,}$' -replace '$', '/'
                    $this.HttpListener.Prefixes.Add($httpPrefix)
                }
            } else {
                # Otherwise, pick a random local loopback port
                $this.HttpListener.Prefixes.Add(
                    "http://127.0.0.1:$(Get-Random -Min 8kb -Max 42kb)/"
                )
            }
        }
       
        # Start the listener
        if (-not $this.HttpListener.IsListening) {
            # and warn that something is listening
            Write-Warning "Listening on $($this.HttpListener.Prefixes)"
            $this.HttpListener.Start()
        }
        
        # Now start our fun little server loop in a thread job.
        $newJob = [Ordered]@{
            ScriptBlock = $this.ServerScript;ArgumentList = $this
            Name = "$($this.HttpListener.Prefixes -replace '/$')"
            ThrottleLimit = 16kb
        }
        if ($this.InitializeScript) {
            $initializationScript = [ScriptBlock]::Create(
                @(
                    foreach ($initScript in $this.InitializeScript) {                        
                        if ($initScript.File -or $initScript -is [string]) {
                            $initScript = 
                                $ExecutionContext.SessionState.InvokeCommand.GetCommand(
                                    $(
                                        if ($initScript.File) {
                                            $initScript.File
                                        } else {
                                            $initScript
                                        }
                                    ), 'ExternalScript'
                                )
                        }
                        if ($initScript -is [Management.Automation.ExternalScriptInfo]) {
                            foreach ($required in $initScript.ScriptBlock.Ast.ScriptRequirements.RequiredModules) {
                                "Import-Module $($required.Name) -Global"
                            }
                            ". '$($initScript.Source -replace "'","''")'"
                        } else {
                            ". {$initScript}"
                        }                        
                    }
                ) -join [Environment]::NewLine
            )
            $this | Add-Member NoteProperty Initialize $InitializationScript -Force
            $newJob.InitializationScript = $initializationScript
        }

        $newJob = Start-ThreadJob @newJob |
            Add-Member NoteProperty HttpListener $this.HttpListener -Force -PassThru |
            Add-Member NoteProperty Fun $this -Force -PassThru
    
        if (-not $this.Jobs) {
            $this | Add-Member NoteProperty Jobs @($newJob) -Force
        } else {
            $null = $this.Jobs += $newJob
        }
        $newJob
    } -Force -PassThru
    #endregion `.Start`


$prefixArguments = $ArgumentList -match '^https?://'

if ($prefixArguments) {
    $OutputObject |
        Add-Member NoteProperty Prefixes (
            $prefixArguments -replace '/?$', '/'
        ) -Force
}

foreach ($verb in 'Build', 'Deploy', 'Start') {
    if ($ArgumentList -contains $verb -or
        $MyInvocation.InvocationName -match "^$verb-") {
        return $outputObject.$Verb.Invoke()
    }
}

# otherwise, output the fun
return $outputObject