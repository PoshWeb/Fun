@{
    name = 'PreviewUpload'
    uses = 'actions/upload-artifact@main'
    with = @{
        name = 'Preview'
        path = '**/preview/**'
    }
    if = '${{always()}}'
}

