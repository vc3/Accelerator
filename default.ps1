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
    Write-Host "PowerShell v$($PSVersionTable.PSVersion)"
    & "$($root)\Accelerator.ps1" -Interactive -y -UseStart -PowerShellVersion 2
}

task Run -depends SetAcceleratorPath,RunAccelerator

task Build -depends BuildChocoPackages

task Deploy -depends DeployChocoPackages

task Default -depends Run
