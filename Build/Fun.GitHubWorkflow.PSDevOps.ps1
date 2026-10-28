#requires -Module PSDevOps
Import-BuildStep -SourcePath (
    Join-Path $PSScriptRoot 'GitHub'
) -BuildSystem GitHubWorkflow

Push-Location ($PSScriptRoot | Split-Path)

New-GitHubWorkflow -Name "Build Fun" -On Push, Demand -Job TestPowerShellOnLinux, 
    TagReleaseAndPublish, 
    buildfun -OutputPath .\.github\workflows\BuildFun.yml  -Env ([Ordered]@{      
        "REGISTRY" = "ghcr.io"
        "IMAGE_NAME" = '${{ github.repository }}'
    })

Pop-Location
