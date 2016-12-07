$here = Split-Path $MyInvocation.MyCommand.Path -Parent

$projectRoot = Split-Path $here -Parent

$ErrorActionPreference = 'Stop'

Import-Module "$($projectRoot)\Modules\Accelerator\Accelerator-StringUtils.psm1" -Force

Describe "ConvertFrom-TemplateString" {
    BeforeEach {
        Push-Location $projectRoot
    }

    It "Should use values from the given hashtable parameter" {
        $str = ConvertFrom-TemplateString 'http://google.com?q={Query}' @{Query='lol+cats'}
        $str | Should Be 'http://google.com?q=lol+cats'
    }

    It "Should use values from environment variables if -UseEnvironmentVariables switch is passed" {
        $str = ConvertFrom-TemplateString 'COMPUTERNAME={COMPUTERNAME}' -UseEnvironmentVariables
        $str | Should Be "COMPUTERNAME=$($env:COMPUTERNAME)"
    }

    It "Should support alternative token delimiters" {
        $str = ConvertFrom-TemplateString 'COMPUTERNAME={COMPUTERNAME}' -UseEnvironmentVariables -Syntax 'CurlyBraces'
        $str | Should Be "COMPUTERNAME=$($env:COMPUTERNAME)"

        $str = ConvertFrom-TemplateString 'COMPUTERNAME=%COMPUTERNAME%' -UseEnvironmentVariables -Syntax 'PercentSigns'
        $str | Should Be "COMPUTERNAME=$($env:COMPUTERNAME)"
    }

    It "Should support using token delimiters as literals using backslash" {
        $str = ConvertFrom-TemplateString 'COMPUTERNAME=\{{COMPUTERNAME}\}' -UseEnvironmentVariables -Syntax 'CurlyBraces'
        $str | Should Be "COMPUTERNAME={$($env:COMPUTERNAME)}"

        $str = ConvertFrom-TemplateString 'COMPUTERNAME=\%%COMPUTERNAME%\%' -UseEnvironmentVariables -Syntax 'PercentSigns'
        $str | Should Be "COMPUTERNAME=%$($env:COMPUTERNAME)%"
    }

    AfterEach {
        Pop-Location
    }
}
