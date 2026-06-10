describe Fun {
    it 'Is Fun To Make a Server' {
        function / { "Hello from Fun" }

        Invoke-RestMethod (
            Start-Fun | Select-Object -ExpandProperty Name
        ) | Should -Be "Hello from Fun"
    }
}
