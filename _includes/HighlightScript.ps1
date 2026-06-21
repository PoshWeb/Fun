<#
.SYNOPSIS
    Includes a highlighted script
.DESCRIPTION
    Includes a highlighted script block.
.NOTES
    This will apply CSS classes to each token within a script block.

    We need to also /_includes/HighlightColors to define the CSS files.
#>
[OutputType('text/html')]
param(
# The script block to highlight
[ScriptBlock]
$ScriptBlock = {}
)

# Stringify our code
$code = "$ScriptBlock"
@(
# Create the `<pre>` and `<code>` blocks.
"<pre><code class='language-powershell'>"

# Tokenize our scripts
$codeTokens = [Management.Automation.PSParser]::Tokenize($code, [ref]$null)
# and keep track of the previous token.
$PreviousToken = $null
# For each token
foreach ($token in $codeTokens) {
    # get the content
    $content = $token.Content
    # variables don't include the `$` or `@`
    if ($token.Type -in 'Variable', 'String') {
        # so fix our content for this special case.
        $content = $code.Substring($token.Start, $token.Length)
    }
    # If there was a previous token
    if ($PreviousToken) {
        # Figure out how far it has been since our previous span,
        $prevEnd = $PreviousToken.Start + $PreviousToken.Length
        # get a substring,
        $substring = $code.Substring($prevEnd, $token.Start -  $prevEnd)
        if ($substring) {
            # and encode it.
            [Web.HttpUtility]::HtmlEncode($substring)
        }
    }
        
    # If we have any content
    if ($content) {
        # create a span of the right CSS class
        "<span class='powershell-$("$($token.Type)".ToLower())'>$(
            # and encode the content
            [Web.HttpUtility]::HtmlEncode($content)
        )</span>"
    }
    
    # Update our previous token pointer
    $PreviousToken = $token
}
# After we have processed all tokens,
"</code></pre>" # close our block.
) -join '' # Output our highlighted codeblock.