#region Eponym

# Functions and scripts are interchangeable in PowerShell
# So we can make a small module using an eponym file.
# First we need to identify the module name 
$moduleName = $MyInvocation.MyCommand.Name -replace '\.psm1$'

# Once we have done this, we can look for an eponymous script: 
$eponym = 
    $ExecutionContext.SessionState.InvokeCommand.GetCommand((
        Join-Path $PSScriptRoot "$moduleName.ps1"
    ), 'ExternalScript')

# If we did not find one,
if (-not $eponym) {
    # warn and return.
    Write-Warning "Missing ./$moduleName.ps1"
    return
}

# We want to define two functions from this script:

# * `Get-$ModuleName`
# * `$moduleName`
$exports = $moduleName, "Get-$ModuleName"

# We can use the function provider to create functions in this scope.
foreach ($functionName in $exports) {
    # This allows us to dynamically set each export to by the eponym
    $ExecutionContext.SessionState.PSVariable.Set(
        "function:$functionName",
        $eponym.ScriptBlock
    )
}

$aliasExports = @(foreach ($attribute in $eponym.ScriptBlock.Attributes) {
    foreach ($alias in $attribute.aliasNames) {
        $ExecutionContext.SessionState.PSVariable.Set(
            "alias:$alias", $moduleName
        )
        $alias
    }
})

$ExecutionContext.SessionState.PSVariable.Set($moduleName, $eponym)

# All that's left to do is explicitly export just these functions.
Export-ModuleMember -Function $exports -Alias $aliasExports -Variable $moduleName
#endregion Eponym