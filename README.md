# Fun
## A Fun Server in PowerShell.

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
