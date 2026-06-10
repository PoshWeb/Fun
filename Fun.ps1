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

    We also want to avoid code injection at all costs,
    and only expose safe commands.    
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
$InputObject
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

Update-TypeData -TypeName $myTypeName -Force -DefaultDisplayPropertySet 'CreatedAt','RequestRate','Functions'
# Create our output object
$outputObject = New-Object PSObject -Property ([Ordered]@{
    PSTypeName = $myTypeName
    CreatedAt  = [DateTime]::Now
    # Fun fact: this kind of enumeration is always up to date
    # We will not need to watch for new commands, this variable will always have them.
    Functions  = $ExecutionContext.SessionState.InvokeCommand.GetCommands('/*','Function,Alias', $true)    
    Arguments  = $ArgumentList
    Input      = $allInput
}) |
    # Extend our output with a script methods and properties
    #region `.Build`
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
                $output = . $cmd
                $path = Join-Path $pwd $cmd.Name
                $newFile = [Ordered]@{
                    Path = Join-Path "." "./$($cmd.Name -replace "^/")"
                    Value=$output -join [Environment]::NewLine
                }
                New-Item @newFile -Force -ItemType File
            } }
    } -Force -PassThru
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
    #endregion `.Clear
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
                        )$(
                            [Environment]::NewLine
                        )}"
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
    #region `.JobScript`
    Add-Member ScriptProperty JobScript { 
        return {
            # All we need to do is pass this object
            param($this)
            
            # It will have a listener
            $httpListener = $this.HttpListener
            # and we can loop while it is listening
            while ($httpListener.IsListening) {
                # Get the next context
                $getContext = $httpListener.GetContextAsync()
                # and wait until it's ready
                while (-not $getContext.Wait(13)) { }
                $context = $getContext.Result
                # If we don't yet have a counter
                if (-not $this.Counter) {
                    # create one.
                    $this | 
                        Add-Member NoteProperty Counter ([long]0) -Force
                }
                # Increment our counter
                $this.Counter++
                # And run our function
                if ($this.Run) {
                    try {
                        $this.Run($context)
                    } catch {
                        $err = $_
                        $context.Response.StatusCode = 400
                        $context.Response.Close([Text.Encoding]::UTF8.GetBytes(
                            "$err"
                        ), $false)
                        $err
                    }                    
                }
            }
        }
    } -Force -PassThru |
    #endregion `.JobScript`
    #region `.Remove`
    Add-Member ScriptMethod Remove {
        param([string]$Wildcard)
        if (-not $Wildcard) { return }
        foreach ($func in $this.Functions) {
            if ($func.Name -notlike $Wildcard) {
                continue
            }
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
            Run the function in a context
        #>
        param($context)

        # Allow for mock requests by enabling casting to uris
        if ($context -as [uri]) {
            $request = [Ordered]@{HttpMethod='Get';Url = $context -as [uri]}
        } else {
            $request, $response = $context.Request, $context.Response
        }

        # Use the local path if present
        $localPath =
            if ($request.Url.LocalPath) {
                $request.Url.LocalPath
            } else { $null }                    
        
        # We want to match the url to a function.
        $functions = @(foreach ($function in @($this.Functions)) {
            # We don't want to be too picky about ending slashes,
            # so remove them from our function name.
            $functionNameNoSlash = $function.Name -replace '/$'
            if (
                # If the local path is like our function name
                $localPath -and 
                    (
                        # we've found our function
                        $localPath -replace '/$' -like $functionNameNoSlash
                    )
            ) {
                # Break after the first function we find.
                $function
                break
            }
        })

        # If there were no found functions
        if (-not $functions) {
            # We're going to send a 404.
            if ($response.StatusCode) {
                $response.StatusCode = 404
            }
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

        # To add to the fun, we want our functions to take parameters
        $query = [Ordered]@{}
        # If the request had a query
        if ($request.Url.Query) {
            # parse it
            $parsedQueryString = [Web.HttpUtility]::ParseQueryString($request.Url.Query)
            # and copy over our parameters.
            foreach ($queryParameter in $parsedQueryString.Keys) {
                $query[$queryParameter] = $parsedQueryString[$queryParameter]
                if ($query[$queryParameter] -match '^(true|false)$') {
                    $query[$queryParameter] = $query[$queryParameter] -match '^true' 
                }
            }
        }
        
        # Get the last matching function 
        $function = $functions[-1]

        # And use its command metadata to find all possible parameters
        $functionParameterMap = @{}
        foreach ($parameter in ($function -as [Management.Automation.CommandMetadata]).Parameters.Values) {
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

        # If the function had an output type like `*/*`
        if ($function.OutputType.Name -like '*/*' -and
            $response.OutputStream
        ) {            
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

        $functionOutput = {
            begin {
                # To stream output, we need to set the protocol version
                $response.ProtocolVersion = '1.1'
                # and send chunked responses.
                $response.SendChunked = $true
                # Get a pointer to the output stream for repeated use.
                $outputStream = $response.OutputStream                
                $encoding = if ($request.ContentEncoding) {
                    $request.ContentEncoding
                } else {
                    [Text.Encoding]::UTF8
                }
            }

            process {
                # Then we need to take each output object
                $in = $_                

                # If it is XML,
                if ($in.OuterXml -and $outputStream.CanWrite) {
                    # write it out.
                    $buffer = $encoding.GetBytes("$($in.OuterXml)")
                    $outputStream.Write($buffer, 0, $buffer.Length)
                    $outputStream.Flush()
                }
                # If it has an HTML property
                elseif ($in.html -and $outputStream.CanWrite) {
                    # write that out
                    $buffer = $encoding.GetBytes("$($in.html)")
                    $outputStream.Write($buffer, 0, $buffer.Length)
                    $outputStream.Flush()
                }
                # Otherwise
                elseif ($outputStream.CanWrite) {
                    # Stringify the result.
                    $buffer = $encoding.GetBytes("$in")
                    $outputStream.Write($buffer, 0, $buffer.Length)
                    $outputStream.Flush()
                } else {
                    $in
                }
            }

            end {                
                # Close our response when the command is done
                if ($response.Close) {
                    $response.Close()
                }
            }
        }

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
            $this | 
                Add-Member NoteProperty HttpListener (
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
            # Write a warning so we know something is listening
            Write-Warning "Listening on $($this.HttpListener.Prefixes)"
            $this.HttpListener.Start()
        }
        
        $listener = $this.HttpListener
        
        # Now start our fun little server loop in a thread job.        
        $newJob = Start-ThreadJob -ScriptBlock $this.JobScript -ArgumentList $this -Name "$(
            $listener.Prefixes -replace '/$'
        )" -ThrottleLimit 16kb |
            Add-Member NoteProperty HttpListener $this.HttpListener -Force -PassThru |
            Add-Member NoteProperty Fun $this -Force -PassThru
    
        if (-not $this.Jobs) {
            $this | Add-Member NoteProperty Jobs @($newJob) -Force -PassThru
        } else {
            $this.Jobs += $newJob
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