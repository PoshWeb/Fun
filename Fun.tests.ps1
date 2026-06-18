describe Fun {
    it 'Is Fun To Make a Server' {
        function / { "Hello from Fun" }
        
        $fun = . ./Fun.ps1
        $job = $fun.Start()

        Invoke-RestMethod $job.Name | 
            Should -Be "Hello from Fun"
        
        $job.HttpListener.Stop()
    }

    it 'Is easy to map query strings' {

        function / { param([int]$Number) $Number }

        $randomNumber = Get-Random
        $job = Start-Fun
        Invoke-RestMethod (
            "$($job.Name)/?number=$randomNumber"
        ) | Should -Be "$randomNumber"
    }

    it 'Can map form data' {
        function / { param([int]$Number) $Number }

        $randomNumber = Get-Random
        $job = Start-Fun
        Invoke-RestMethod $job.Name -Method POST -Body "number=$randomNumber" -ContentType (
            'application/x-www-form-urlencoded'
        )  | Should -Be "$randomNumber"
        $job.HttpListener.Stop()
    }

    it 'Can map json data' {
        function / { param([int]$Number) $Number }

        $randomNumber = Get-Random
        $job = Start-Fun
        Invoke-RestMethod $job.Name -Method POST -Body (
            @{number=$randomNumber} | ConvertTo-Json
        ) -ContentType (
            'application/json'
        )  | Should -Be "$randomNumber"
        $job.HttpListener.Stop()
    }
}
