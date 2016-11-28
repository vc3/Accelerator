$root = Split-Path $MyInvocation.MyCommand.Path -Parent
Write-Host "root=$root"
include '.\Modules\Psake-Choco\tasks.ps1'
properties {
    if ($env:ChocolateyLocal -and (Test-Path $env:ChocolateyLocal)) {
        $outDir = $env:ChocolateyLocal
    } else {
        $outDir = Join-Path $env:LOCALAPPDATA 'Accelerator'
        if (-not(Test-Path $outDir)) {
            New-Item $outDir -Type Directory | Out-Null
        }
    }

    $chocoOutDir = $outDir
    $chocoPkgsDir = $root
}

if (Test-Path "$($root)\psake-local.ps1") {
    include "$($root)\psake-local.ps1"
}

task SetAcceleratorPath {
    if ($acceleratorPath) {
        $env:AcceleratorPath = $acceleratorPath
    }
}

task RunAccelerator {
    $global:PSModulesRoot = "$($root)\Modules"
    Write-Host "PowerShell v$($PSVersionTable.PSVersion)"
    & "$($root)\Chocolatey\content\Accelerator.ps1" -Interactive -y
}

task BuildBatFileRunner {
    Import-Module "$($root)\Modules\Assemble\Assemble.psd1"
    Invoke-ScriptBuild -Name 'Accelerator' -SourcePath "$($root)\BatFileRunner" -TargetPath "$($root)\Chocolatey\content\Accelerator.ps1" -Force -Silent
}

task BuildPowerShellModule {
    Import-Module "$($root)\Modules\Assemble\Assemble.psd1"
    Invoke-ScriptBuild -Name 'Accelerator' -SourcePath "$($root)\Scripts" -TargetPath "$($root)\Chocolatey\content\Accelerator.psm1" -Export 'Start-Accelerator','Read-Confirmation' -Force -Silent
}

task Run -depends BuildBatFileRunner,BuildPowerShellModule,SetAcceleratorPath,RunAccelerator

task Build -depends BuildBatFileRunner,BuildPowerShellModule,BuildChocoPackages

task Deploy -depends DeployChocoPackages

task Default -depends Run
