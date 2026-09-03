describe Fun {
    BeforeAll {
        New-Module -Name Foo -ScriptBlock {
            function /hi { "Hello from Fun" }
            function /query { param([int]$Number) $Number }

            function /form { param([int]$Number) $Number }

            function /json { param([int]$Number) $Number }

            function /args/* { $args }

            function /named/:named {
                param($named)
                $Named
            }

            function /socket {                
                param(
                [double]$Number
                )
                
                if ($request.IsWebSocketRequest) {
                    if ($Number) {
                        [Ordered]@{number = $Number}
                    } else {
                        [Ordered]@{number = Get-Random}
                    }                    
                } else {
                    
                }
            }
        } | Import-Module -Global

        $funJob = Start-Fun
    }
    it 'Is Fun To Make a Server' {                        
        Invoke-RestMethod "$($funJob.Name)/hi" | 
            Should -Be "Hello from Fun"                
    }

    it 'Is easy to map query strings' {        
        $randomNumber = Get-Random
        Invoke-RestMethod (
            "$($funJob.Name)/query/?number=$randomNumber"
        ) | Should -Be "$randomNumber"

    }

    it 'Can map form data' {
        $randomNumber = Get-Random
        Invoke-RestMethod "$($funJob.Name)/form" -Method POST -Body "number=$randomNumber" -ContentType (
            'application/x-www-form-urlencoded'
        )  | Should -Be "$randomNumber"        
    }

    it 'Can map json data' {        
        $randomNumber = Get-Random
        Invoke-RestMethod "$($funJob.Name)/json" -Method POST -Body (
            @{number=$randomNumber} | ConvertTo-Json
        ) -ContentType (
            'application/json'
        )  | Should -Be "$randomNumber"
    }

    it 'Can map positional arguments' {
        $randomNumber = Get-Random        
        Invoke-RestMethod "$($funJob.Name)/args/$randomNumber" | Should -Be "$randomNumber"        
    }

    it 'Can map positional named parameters' {
        $randomNumber = Get-Random        
        Invoke-RestMethod "$($funJob.Name)/named/$randomNumber/" | Should -Be "$randomNumber"        
    }
}
