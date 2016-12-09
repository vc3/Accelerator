$here = Split-Path $MyInvocation.MyCommand.Path -Parent

$projectRoot = Split-Path $here -Parent

$ErrorActionPreference = 'Stop'

Import-Module "$($projectRoot)\Modules\Accelerator\Accelerator-Configuration.psm1" -Force

$acceleratorRootBefore = $global:AcceleratorRoot

Describe "Get-ConfigurationValue" {
    BeforeEach {
        Push-Location $projectRoot
        $global:AcceleratorRoot = "$($projectRoot)\Tests\TestData"
    }

    It "Should return a simple string value" {
        Get-ConfigurationValue -Name 'Name' | Should Be 'John Doe'
    }

    It "Should trim string values" {
        Get-ConfigurationValue -Name 'Nickname' | Should Be 'JD'
    }

    It "Should infer types by default (int)" {
        Get-ConfigurationValue -Name 'Age' | Should Be 30
        (Get-ConfigurationValue -Name 'Age').GetType().Name | Should Be 'Int32'
    }

    It "Should infer types by default (DateTime)" {
        Get-ConfigurationValue -Name 'DOB' | Should Be '03/21/2015 08:10:00'
        (Get-ConfigurationValue -Name 'DOB').GetType().Name | Should Be 'DateTime'
    }

    It "Should infer types by default (string[])" {
        ((Get-ConfigurationValue -Name 'Children') -join ',') | Should Be 'Bob,Mary,Tom'
        (Get-ConfigurationValue -Name 'Children').GetType().Name | Should Be 'Object[]'
    }

    It "Should return the value as the requested type" {
        Get-ConfigurationValue -Name 'Name' -Type 'string' | Should Be 'John Doe'
        Get-ConfigurationValue -Name 'Age' -Type 'string' | Should Be '30'
        Get-ConfigurationValue -Name 'DOB' -Type 'string' | Should Be '3/21/2015 8:10:00'
        Get-ConfigurationValue -Name 'Children' -Type 'string' | Should Be 'Bob, Mary, Tom'
        ((Get-ConfigurationValue -Name 'Age' -Type 'Array') -join ',') | Should Be '30'
    }

    AfterEach {
        $global:AcceleratorRoot = $acceleratorRootBefore
        Pop-Location
    }
}
