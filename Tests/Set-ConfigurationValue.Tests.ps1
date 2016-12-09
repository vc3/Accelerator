$here = Split-Path $MyInvocation.MyCommand.Path -Parent

$projectRoot = Split-Path $here -Parent

$ErrorActionPreference = 'Stop'

Import-Module "$($projectRoot)\Modules\Accelerator\Accelerator-Configuration.psm1" -Force

$acceleratorRootBefore = $global:AcceleratorRoot

Describe "Get-ConfigurationValue" {
    BeforeEach {
        Push-Location $projectRoot
        $global:AcceleratorRoot = "$($projectRoot)\Tests\TestData"
        $originalContent = Get-Content "$($projectRoot)\Tests\TestData\TestData.cfg" -Raw
    }

    It "Should append a new value to the file" {
        Set-ConfigurationValue -Name 'EyeColor' -Value 'Blue'
        Get-Content "$($projectRoot)\Tests\TestData\TestData.cfg" -Raw | Should Be ($originalContent + "EyeColor=Blue`r`n")
    }

    It "Should replace an existing value in the file" {
        Set-ConfigurationValue -Name 'Children' -Value ' Bob, Mary, Tom, Sue'
        Get-Content "$($projectRoot)\Tests\TestData\TestData.cfg" -Raw | Should Be ($originalContent.Trim() + ", Sue`r`n")
    }

    AfterEach {
        $originalContent.Trim() | Out-File "$($projectRoot)\Tests\TestData\TestData.cfg" -Encoding UTF8
        $global:AcceleratorRoot = $acceleratorRootBefore
        Pop-Location
    }
}
