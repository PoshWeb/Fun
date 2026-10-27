@{
    name = 'PreviewUpload'
    uses = 'actions/upload-artifact@main'
    with = @{
        name = 'FunPreview'
        path = '**/preview/**'
    }
    if = '${{always()}}'
}

