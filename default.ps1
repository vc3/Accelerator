$root = Split-Path $MyInvocation.MyCommand.Path -Parent
Write-Host "root=$root"

properties {
    if ($env:ChocolateyLocal -and (Test-Path $env:ChocolateyLocal)) {
        $outDir = $env:ChocolateyLocal
    } else {
        $outDir = Join-Path $env:LOCALAPPDATA 'Accelerator'
        if (-not(Test-Path $outDir)) {
            New-Item $outDir -Type Directory | Out-Null
        }
    }

    $psVersion = 0

    $chocoOutDir = $outDir
    $chocoPkgsDir = $root

    $acceleratorNewWindow = $false

    $acceleratorCommand = $null

    $acceleratorFunction = $null

    $acceleratorParams = @{}
}

if (Test-Path "$($root)\psake-local.ps1") {
    include "$($root)\psake-local.ps1"
}

include '.\Modules\Psake-Choco\tasks.ps1'

properties {
    $acceleratorScript = "$($root)\Accelerator.ps1"
}

task SetAcceleratorPath {
    if ($acceleratorPath) {
        $env:AcceleratorPath = $acceleratorPath
    } else {
        $env:AcceleratorPath = "$(Split-Path $PROFILE -Parent)"
    }
}

task SetAcceleratorInteractive {
    $env:AcceleratorInteractive = $true
}

task RunAccelerator {
    Write-Host "PowerShell v$($PSVersionTable.PSVersion)"

    if ($psVersion -gt 0) {
        $acceleratorNewWindow = $true
        $acceleratorParams['PowerShellVersion'] = $psVersion
    }

    if ($acceleratorNewWindow) {
        $acceleratorParams['UseStart'] = $true
    }

    if ($env:AcceleratorInteractive) {
        $acceleratorParams['Interactive'] = $true
        $acceleratorParams['Confirm'] = $true
    }

    if ($acceleratorCommand) {
        $acceleratorParams['CommandName'] = $acceleratorCommand
    }

    if ($acceleratorFunction) {
        $acceleratorParams | ForEach-Object { &$acceleratorFunction }
    } else {
        & $acceleratorScript @acceleratorParams
    }
}

task Run -depends SetAcceleratorPath,SetAcceleratorInteractive,RunAccelerator

task RunNoUI -depends SetAcceleratorPath,RunAccelerator

task Prompt -depends SetAcceleratorPath {
    powershell -Version 2 -NoProfile
}

task Build -depends BuildChocoPackages

## Currently this would push all nupkg files in the output directory
# task Deploy -depends DeployChocoPackages

task Default -depends Run
