<#
.SYNOPSIS
    Includes a CopyCode button
.DESCRIPTION
    Includes a copy-to-clipboard near all code blocks.
#>
[OutputType('text/html')]
param()
"<style>.copy-button { float: right; }</style>"
"
<script>
document.querySelectorAll('pre > code').forEach(element => {
    const copyCodeButton = document.createElement('div')
    copyCodeButton.classList.add('copy-button')
    copyCodeButton.onclick = () => navigator.clipboard.writeText(element.innerText)
    copyCodeButton.innerHTML = ``$(
        /_includes/FeatherIcon -Icon 'clipboard'
    )``
    element.parentNode.prepend(copyCodeButton)
});
</script>
"