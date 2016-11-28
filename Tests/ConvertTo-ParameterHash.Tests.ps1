$here = Split-Path $MyInvocation.MyCommand.Path -Parent

$projectRoot = Split-Path $here -Parent

$ErrorActionPreference = 'Stop'

Describe "ConvertTo-ParameterHash" {
    BeforeEach {
        Push-Location $projectRoot
    }

    It "Should parse simple `"-Name 'Value'`" arguments" {
        $params = & "$($projectRoot)\Scripts\ConvertTo-ParameterHash.ps1" -List @("-Name", "John Doe", "-Age", "40")
        $params.Keys | Should Be @('Name','Age')
        $params['Name'] | Should Be 'John Doe'
        $params['Age'] | Should Be 40

        $params = & "$($projectRoot)\Scripts\ConvertTo-ParameterHash.ps1" -String "-Name 'John Doe' -Age 40"
        $params.Keys | Should Be @('Name','Age')
        $params['Name'] | Should Be 'John Doe'
        $params['Age'] | Should Be 40
    }

    It "Should parse a positional argument" {
        $positionalArgs = @('Name')

        $params = & "$($projectRoot)\Scripts\ConvertTo-ParameterHash.ps1" -List @("John Doe") -PositionalParameters $positionalArgs
        $params.Keys | Should Be @('Name')
        $params['Name'] | Should Be 'John Doe'

        $params = & "$($projectRoot)\Scripts\ConvertTo-ParameterHash.ps1" -String "'John Doe'" -PositionalParameters $positionalArgs
        $params.Keys | Should Be @('Name')
        $params['Name'] | Should Be 'John Doe'
    }

    It "Should parse a positional argument and named arguments" {
        $positionalArgs = @('Name')

        $params = & "$($projectRoot)\Scripts\ConvertTo-ParameterHash.ps1" -List @("John Doe", "-Age", "40") -PositionalParameters $positionalArgs
        $params.Keys | Should Be @('Name', 'Age')
        $params['Name'] | Should Be 'John Doe'
        $params['Age'] | Should Be '40'

        $params = & "$($projectRoot)\Scripts\ConvertTo-ParameterHash.ps1" -String "'John Doe' -Age 40" -PositionalParameters $positionalArgs
        $params.Keys | Should Be @('Name', 'Age')
        $params['Name'] | Should Be 'John Doe'
        $params['Age'] | Should Be '40'
    }

    It "Should parse multiple positional arguments" {
        $positionalArgs = @('Name', 'Age')

        $params = & "$($projectRoot)\Scripts\ConvertTo-ParameterHash.ps1" -List @("John Doe", "40") -PositionalParameters $positionalArgs
        $params.Keys | Should Be @('Name', 'Age')
        $params['Name'] | Should Be 'John Doe'
        $params['Age'] | Should Be '40'

        $params = & "$($projectRoot)\Scripts\ConvertTo-ParameterHash.ps1" -String "'John Doe' 40" -PositionalParameters $positionalArgs
        $params.Keys | Should Be @('Name', 'Age')
        $params['Name'] | Should Be 'John Doe'
        $params['Age'] | Should Be '40'
    }

    It "Should parse a command switch" {
        $params = & "$($projectRoot)\Scripts\ConvertTo-ParameterHash.ps1" -List @("-Foo")
        $params.Keys | Should Be @('Foo')
        $params['Foo'] | Should Be $true

        $params = & "$($projectRoot)\Scripts\ConvertTo-ParameterHash.ps1" -String "-Foo"
        $params.Keys | Should Be @('Foo')
        $params['Foo'] | Should Be $true
    }

    It "Should parse a combination of arguments (1)" {
        $positionalArgs = @('Name')
        $params = & "$($projectRoot)\Scripts\ConvertTo-ParameterHash.ps1" -List @("Foobar", "-p", "/path/to/file", "-v") -PositionalParameters $positionalArgs
        $params.Keys | Should Be @('Name', 'p', 'v')
        $params['Name'] | Should Be 'Foobar'
        $params['p'] | Should Be '/path/to/file'
        $params['v'] | Should Be $true
    }

    AfterEach {
        Pop-Location
    }
}
