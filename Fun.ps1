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
.EXAMPLE
    # Hello World server
    / { "<h1>hello world</h1>" }

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
[Alias('Start-Fun')]
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
                $functionNameNoSlash = $function.Name -replace '/$'
                if (
                    # If the local path is like our function name
                    $localPath -and (
                        # we've found our function
                        $localPath -replace '/$' -like $functionNameNoSlash
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


# A script block used to output http requests.
[ScriptBlock]
$HttpOutput = {
    # CGI requests just need to close
    $response.Close(
        # with a buffer holding all the output
        $encoding.GetBytes((@(
            foreach ($in in @($input)) {
                $inXml = $in.OuterXml
                if ($inXml) {"$inXml"}
                elseif ($($inHtml = $in.html;$inHtml)) {"$inHtml"}
                else {"$in"}
            }
        ) -join '')),
        $false
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
            $buffer = $encoding.GetBytes(
                $(
                    $inXml = $in.OuterXml
                    if ($inXml) {"$inXml"}
                    elseif (
                        $($inHtml = $in.html;$inHtml)
                    ) {"$inHtml"}
                    else {"$in"}
                )
            )
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
    param($this)
    # It will have a listener
    $httpListener = $this.HttpListener
    
    # and we can loop while it is listening
    if (-not $this.Counter) {            
        $this | Add-Member NoteProperty Counter ([long]0) -Force
    }
    
    while ($httpListener.IsListening) {
        # Get the next context
        $getContext = $httpListener.GetContextAsync()
        # and wait until it's ready
        while (-not $getContext.Wait(11)) { }
        $context = $getContext.Result        
        # Run our function
        # If we don't yet have a counter, create one.
        $request, $response = $context.Request, $context.Response
        
        # Increment our counter
        $this.Counter++

        try {
            $this.Run($context)
        } catch {
            $err = $_
            $response.StatusCode = 400
            $response.Close([Text.Encoding]::UTF8.GetBytes(
                "$err"
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
            Write-Error -Exception $receivingWebSocket.Exception -Category ProtocolError
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
                $socketMessage
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

Update-TypeData -TypeName $myTypeName -Force -DefaultDisplayPropertySet 'CreatedAt','Prefix','Functions'

# Create a dictionary for our output object
$output = [Ordered]@{PSTypeName = $myTypeName}
foreach ($key in $MyInvocation.MyCommand.Parameters.Keys) {
    $var = $ExecutionContext.SessionState.PSVariable.get($key)
    if ($var) { $output[$key] = $var.Value }
}

# Initialize it with a number of functions
$output.CreatedAt  = [DateTime]::Now
$output.Functions  = $ExecutionContext.SessionState.InvokeCommand.GetCommands(
    '*/*','Function,Alias', $true
)
$output.Arguments  = $ArgumentList
$output.Input      = $allInput

# Create our object and extend it
$outputObject = New-Object PSObject -Property $output |
    #region `.Build()`
    Add-Member ScriptMethod Build {
        <#
        .SYNOPSIS
            Builds the server 
        .DESCRIPTION
            Builds the server into a static site.
        
            Will build any `/` function whose name is like *.*.
        #>
        param([string]$Path = $pwd)
        $this.Functions |
            . { process {
                $cmd = $_
                if ($cmd.Name -notlike '*.*') { return }                
                if ($cmd.Name -match '\*') { return }
                $output = . $cmd
                $path =  Join-Path "." "./$($cmd.Name -replace "^/")"
                $newFile = [Ordered]@{
                    Path = $path
                    Value=$output -join [Environment]::NewLine
                }
                New-Item @newFile -Force -ItemType File
            } }
    } -Force -PassThru |
    #endregion `.Build`
       
    #region `.Clear`
    Add-Member ScriptMethod Clear {
        foreach ($func in $this.Functions) {
            if ($func -is [Management.Automation.FunctionInfo]) {
                Remove-Item "function:/$($func.Name)"
            } elseif ($func -is [Management.Automation.AliasInfo]) {
                Remove-Item "alias:/$($func.Name)"
            }
        }
    } -Force -PassThru |
    #endregion `.Clear`
    #region `.Prefix`
    Add-Member ScriptProperty Prefix {
        if ($this.HttpListener.Prefixes.Length -eq 1) {
            $this.HttpListener.Prefixes[0]
        } else {
            $this.HttpListener.Prefixes
        }
    } -Force -PassThru |
    #endregion `.Prefix
   
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
        
    #region `.Remove`
    Add-Member ScriptMethod Remove {
        param([string]$Wildcard)
        if (-not $Wildcard) { return }
        foreach ($func in $this.Functions) {
            if ($func.Name -notlike $Wildcard) { continue }
            if ($func -is [Management.Automation.FunctionInfo]) {
                Remove-Item "function:/$($func.Name)"
            } elseif ($func -is [Management.Automation.AliasInfo]) {
                Remove-Item "alias:/$($func.Name)"
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
        param($context, $data)

        # Allow for mock requests by enabling casting to uris
        if ($context -as [uri]) {
            $request = [Ordered]@{HttpMethod='Get';Url = $context -as [uri]}
        } elseif ($context.context) {
            $request, $response = $context.Context.Request, $context.Context.Response
        } else {
            $request, $response = $context.Request, $context.Response
        }
        
        # WebSocket handshake requests should be specially handled before we route to a function.
        if ($Request.IsWebSocketRequest -and -not $context.WebSocket) {
            if ($this.NoWebSocket) {
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
            if (-not $this.Sockets) {
                # create a dictionary to hold them.
                $this | Add-Member NoteProperty Sockets ([Ordered]@{}) -Force
            }

            # If we do not have any sockets on this url
            if (-not $this.Sockets[$request.Url]) {
                # create a list
                $this.Sockets[$request.Url] = @()
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
            
            # Each websocket runs in its own thread job
            $socketJob = Start-ThreadJob -Name "$(
                $request.Url
            )" -ScriptBlock $this.SocketJob -ArgumentList $this, $socketInfo -ThrottleLimit 32kb  |
                Add-Member NoteProperty HttpListener $this.HttpListener -Force -PassThru |
                Add-Member NoteProperty SocketInfo $socketInfo -Force -PassThru |
                Add-Member NoteProperty WebSocket $socketInfo.WebSocket -Force -PassThru |
                Add-Member NoteProperty Fun $this -Force -PassThru
            
            $urlString = "$($request.Url)"
            $this.Sockets[$urlString] += $socketJob

            # While we're here, might as well clean up finished socket jobs.
            $toRemove = @()
            $this.Sockets[$urlString] = # Make one pass thru all sockets to this url
                @(foreach ($socket in $this.Sockets[$urlString]) {
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
        $url
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
                $response.Close()
                return
            }
        }

        # After we've routed, get the last matching function. 
        $function = $functions[-1]

        # If we have not mapped a function, return.
        if (-not $function) { return }

        # To add to the fun, we want our functions to take parameters
        $query = [Ordered]@{}
        # If the request had a query, parse it.
        if ($request.Url.Query) {
            $parsedQueryString = [Web.HttpUtility]::ParseQueryString($request.Url.Query)
            # Then copy over our parameters.
            foreach ($queryParameter in $parsedQueryString.Keys) {
                $query[$queryParameter] = $parsedQueryString[$queryParameter]
                if ($query[$queryParameter] -match '^(true|false)$') {
                    $query[$queryParameter] = $query[$queryParameter] -match '^true'
                }
            }
        }
        
        # If the method is POST and we can read input
        if ($Method -eq 'POST' -and $request.InputStream.CanRead) {
            # and we are dealing with `x-www-form-urlencoded` form data
            if (
                $request.ContentType -eq 'application/x-www-form-urlencoded'
            ) {
                $reader = [IO.StreamReader]::new($request.InputStream)
                $Body = $reader.ReadToEnd()
                $reader.Close(),$reader.Dispose()
                # Read the input            
                $parsedQueryString = [Web.HttpUtility]::ParseQueryString($Body)
                foreach ($queryParameter in $parsedQueryString.Keys) {
                    $query[$queryParameter] = $parsedQueryString[$queryParameter]
                    if ($query[$queryParameter] -match '^(true|false)$') {
                        $query[$queryParameter] = $query[$queryParameter] -match '^true'
                    }
                }
            }
            elseif ($request.ContentType -eq 'application/json') {
                $reader = [IO.StreamReader]::new($request.InputStream)
                $Body = $reader.ReadToEnd()
                $reader.Close(),$reader.Dispose()

                try {
                    $parsedBody = ConvertFrom-Json -InputObject $body
                    foreach ($property in $parsedBody.psobject.properties) {
                        $query[$property] = $parsedBody.($property.Name)
                    }
                } catch {
                    $ex = $_
                    $response.StatusCode = 400
                    $response.Close([Text.Encoding]::UTF8.GetBytes(
                        "$ex"
                    ), $false)
                    return
                }
            }
        }

        # And use its command metadata to find all possible parameters
        $functionParameterMap = @{}
        foreach ($parameter in @((
            $function -as [Management.Automation.CommandMetadata]
        ).Parameters.Values)) {
            $functionParameterMap[$parameter.Name] = $parameter
            foreach ($alias in $parameter.Aliases) {
                $functionParameterMap[$alias] = $parameter
            }
        }
        
        # Now take all of our query parameters
        $functionParameters = [Ordered]@{}
        foreach ($queryParameter in $query.Keys) {
            # and map them to the function where we can
            $functionParameter = $functionParameterMap[$queryParameter]
            if ($functionParameter) {
                $functionParameters[
                    $functionParameter.Name
                ] = $query[$queryParameter]
            }
        }

        # If we passed a data object, walk over its properties
        foreach ($property in $data.psobject.properties) {
            # and map them to the function where we can.
            $functionParameter = $functionParameterMap[$property.Name]
            if ($functionParameter) {
                $functionParameters[$functionParameter.Name] =
                    $data.$($property.Name)
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

        $encoding = [Text.Encoding]::UTF8
        
        # We need to determine how we will handle function output.
        $FunctionOutput =
        # We do not always want to stream content
            if ($(
                # we should only stream if `$this` or the `$function` say so.
                $this.Stream
            )) {
                if ($request.IsWebSocketRequest) {
                    # If we are streaming a websocket request
                    $this.WebSocketStreamOutput
                } else {
                    $this.HttpStreamOutput
                }
            } else {
                # If we are not streaming, output is easier
                if ($request.IsWebSocketRequest) {
                    $this.WebSocketOutput
                } else {
                    $this.HttpOutput
                }
            }
        
        $functionOutput = $functionOutput.GetNewClosure()
        
        # Call our function and stream the results
        try {
            . $function @functionParameters *>&1 | 
                . $functionOutput
        } catch {
            $err = $_
            $response.StatusCode = 400
            $response.Close([Text.Encoding]::UTF8.GetBytes(
                "$err"
            ), $false)
            $err
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
            # If we have any prefixes, add them
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
            ScriptBlock = $this.ServerScript
            ArgumentList = $this
            Name = "$($this.HttpListener.Prefixes -replace '/$')"
            ThrottleLimit = 16kb
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
# If the arguments contained `start`
if ($ArgumentList -contains 'Start' -or 
    # or the invocation name started with `Start-`
    $MyInvocation.InvocationName -match '^Start-') {
    # start the fun now.  
    $outputObject.Start()
} else {
    # otherwise, output the fun
    $outputObject
}

return