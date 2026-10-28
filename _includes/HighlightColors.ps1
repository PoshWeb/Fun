<#
.SYNOPSIS
    Includes Highlight Colors
.DESCRIPTION
    Includes Highlight Colors for PowerShell Scripts
#>
[OutputType('text/css')]
param(
# PowerShell Attribute css properties
[psobject]$Attribute = 'color: var(--cyan); font-weight: bold;',
# PowerShell Command css properties
[psobject]$Command = 'color: var(--cyan);  font-weight: bold;',
# PowerShell CommandArgument css properties
[psobject]$CommandArgument = "color: var(--cyan); font-weight: bolder;",
# PowerShell CommandParameter css properties
[psobject]$CommandParameter = 'color: var(--brightCyan); font-weight: bold;',
# PowerShell Comment css properties
[psobject]$Comment = "color: var(--green);",
# PowerShell GroupEnd css properties
[psobject]$GroupEnd = 'color: var(--purple); font-weight: bolder;',
# PowerShell GroupStart css properties
[psobject]$GroupStart = 'color: var(--purple); font-weight: bolder;',
# PowerShell Keyword css properties
[psobject]$Keyword = "color: var(--cyan); font-weight: bolder;",
# PowerShell LineContinuation css properties
[psobject]$LineContinuation,
# PowerShell LoopLabel css properties
[psobject]$LoopLabel = "color: var(--brightCyan);  font-weight: bold;",
# PowerShell Member css properties
[psobject]$Member,
# PowerShell NewLine css properties
[psobject]$NewLine,
# PowerShell Number css properties
[psobject]$Number,
# PowerShell Operator css properties
[psobject]$Operator = 'color: var(--cyan); font-weight: bold;',
# PowerShell Position css properties
[psobject]$Position,
# PowerShell StatementSeparator css properties
[psobject]$StatementSeparator,
# PowerShell String css properties
[psobject]$String = 'color: var(--brightCyan)',
# PowerShell Type css properties
[psobject]$Type,
# PowerShell Unknown css properties
[psobject]$Unknown,
# PowerShell Variable css properties
[psobject]$Variable = "color: var(--yellow);"
)

# Get our metadata
$myMetadata = [Management.Automation.CommandMetadata]$MyInvocation.MyCommand
# walk over each of our parameters
foreach ($parameterName in $myMetadata.Parameters.Keys) {
    # and get the parameter variable.
    $var = $ExecutionContext.SessionState.PSVariable.Get($parameterName)
    $css = 
        # If it is a string
        if ($var.value -is [string]) {
            $var.value # include it inline.
        }
        # If it is a dictionary
        elseif ($var.value -is [Collections.IDictionary]) {
            # Include each key/value pair
            @(foreach ($key in $var.Value.keys) {
                $key, $var.Value[$key] -join ':'
            }) -join ';'
        }
        # If it is a psobject
        elseif ($var.value -is [PSObject]) {
            # Include each property/value
            @(foreach ($property in $var.Value.psobject.properties) {
                $property.Name, $var.Value.($property.Name) -join ':'
            }) -join ';'
        }

    # If we had a CSS value for this parameter 
    if ($css) {
        # declare a selector with that value.
        ".powershell-$($parameterName.ToLower()) { $css }"
    }
}