@{
    name = 'PreviewUpload'
    uses = 'actions/upload-artifact@main'
    with = @{
        name = 'Preview'
        path = '**Preview**'
    }
    if = '${{always()}}'
}

