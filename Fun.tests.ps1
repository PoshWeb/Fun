describe Fun {
    BeforeAll {
        New-Module -Name Foo -ScriptBlock {
            function /hi { "Hello from Fun" }
            function /query { param([int]$Number) $Number }

            function /form { param([int]$Number) $Number }

            function /json { param([int]$Number) $Number }
        } | Import-Module -Global        
    }
    it 'Is Fun To Make a Server' {        
        $job = Start-Fun
        
        Invoke-RestMethod "$($job.Name)/hi" | 
            Should -Be "Hello from Fun"
        
        $job.HttpListener.Stop()
    }

    it 'Is easy to map query strings' {        
        $randomNumber = Get-Random
        $job = Start-Fun
        Invoke-RestMethod (
            "$($job.Name)/query/?number=$randomNumber"
        ) | Should -Be "$randomNumber"
        $job.HttpListener.Stop()
    }

    it 'Can map form data' {    
        $randomNumber = Get-Random
        $job = Start-Fun
        Invoke-RestMethod "$($job.Name)/form" -Method POST -Body "number=$randomNumber" -ContentType (
            'application/x-www-form-urlencoded'
        )  | Should -Be "$randomNumber"
        $job.HttpListener.Stop()
    }

    it 'Can map json data' {        
        $randomNumber = Get-Random
        $job = Start-Fun
        Invoke-RestMethod "$($job.Name)/json" -Method POST -Body (
            @{number=$randomNumber} | ConvertTo-Json
        ) -ContentType (
            'application/json'
        )  | Should -Be "$randomNumber"
        $job.HttpListener.Stop()
    }
}
