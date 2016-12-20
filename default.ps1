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

    $psVersion = 2
    $chocoOutDir = $outDir
    $chocoPkgsDir = $root
}

if (Test-Path "$($root)\psake-local.ps1") {
    include "$($root)\psake-local.ps1"
}

task SetAcceleratorPath {
    if ($acceleratorPath) {
        $env:AcceleratorPath = $acceleratorPath
    } else {
        $env:AcceleratorPath = "$(Split-Path $PROFILE -Parent)"
    }
}

task RunAccelerator {
    Write-Host "PowerShell v$($PSVersionTable.PSVersion)"
    & "$($root)\Accelerator.ps1" -Interactive -y -UseStart -PowerShellVersion $psVersion
}

task Run -depends SetAcceleratorPath,RunAccelerator

task Prompt -depends SetAcceleratorPath {
    powershell -Version 2 -NoProfile
}

task Build -depends BuildChocoPackages

task Deploy -depends DeployChocoPackages

task Default -depends Run
