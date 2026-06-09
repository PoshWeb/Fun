# Fun Security

`Fun` is an experimental web server designed to be run locally.

`Fun` maps any functions whose names start with `/` to a web request.

## Fun Security Boundary

Functions run as the current user, in the current context.

This means the primary security boundary of fun is you.

`Fun` should generally not require you running as an administrator.

By default, fun runs on a random local loopback port.

This means that only your machine can access it (and only your current process will know where it is).

Anything within the same PowerShell runspace can define a new command for that listener to execute.

Existing commands can be used by aliasing them.

This server is you, running as you, and capable of doing anything you can do.

If your code allows for code injection, requests can execute as you.

In order to avoid maliciousness, please:

1. Only expose a small number of commands
2. Do not use `Invoke-Expression`
3. Do not expand strings
4. Do not dynamically define variables

## Fun Containers

Fun can run in a container for additional isolation.  

When running fun in a container, it is possible to further isolate the functionality.

Only the fun you allow will be defined, and thus, only the fun you defined can be run within the container.

## Fun Denial of Service

Because fun runs whatever you say it runs, slow scripts will slow down response rates.

If you are using `Fun` for fun local development, this is unlikely to cause an issue.

If you are using `Fun` for remote development, your functions performance will dictate the server performance.

Please try to write fun fast functions.

Additionally, because `Fun` runs as you in the current session, exposing commands that interact with the host can block requests.

For example, `Set-Alias /Read/Host Read-Host` will map `Read-Host` to the `/Read/Host` url.  Visiting `/Read/Host` will prompt for host input _in the terminal, not the browser_.

For this reason, it is recommended that you do not directly expose any commands with host interactivity as a public endpoint.