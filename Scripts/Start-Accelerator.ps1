$PSModuleAutoloadingPreference = 'None'

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

$setPSScriptRoot = $false

if (-not($PSScriptRoot)) {
    $setPSScriptRoot = $true
    Write-Verbose "Setting 'PSScriptRoot' variable since it isn't automatically set by the runtime..."
    $PSScriptRoot = Split-Path $script:MyInvocation.MyCommand.Path
}

Import-Module "$($PSScriptRoot)\..\Accelerator.psd1"

$positionalParameters = @('Command')

Write-Verbose "Parsing parameters..."
$parameterHash = $Args | .\ConvertTo-ParameterHash.ps1 -PositionalParameters $positionalParameters -ErrorAction Stop

Write-Verbose "Parameters:`r`n$(($parameterHash.Keys | foreach { (' ' * 11) + (.\ConvertTo-RightPaddedString.ps1 $_ 20) + '=' + $parameterHash[$_] }) -join "`r`n")"

if (-not($parameterHash['WorkingDirectory'])) {
    $parameterHash['WorkingDirectory'] = $PWD.Path
}

$interactive = $parameterHash['Interactive']
$useStart = $parameterHash['UseStart']
$persistCredentials = $parameterHash['PersistCredentials']
$windowTitle = $parameterHash['WindowTitle']

if ($parameterHash['Command']) {
    $command = $parameterHash['Command']
    $parameterHash.Remove('Command')
} elseif ($interactive) {
    $command = $null
} else {
    throw "A command must be specified when run in non-interactive mode."
}

if ($windowTitle) {
    $host.ui.RawUI.WindowTitle = $windowTitle
} elseif ($interactive) {
    $host.ui.RawUI.WindowTitle = "Accelerator"
}

if (Test-Path "$($PSScriptRoot)\..\Accelerator.version") {
    $version = (Get-Content "$($PSScriptRoot)\..\Accelerator.version").Trim()
} elseif (Test-Path "$($PSScriptRoot)\..\Chocolatey\Accelerator.nuspec") {
    $version = ([xml](Get-Content "$($PSScriptRoot)\..\Chocolatey\Accelerator.nuspec")).package.metadata.version.Trim()
} else {
    $version = '???'
}

Write-Host "Accelerator v$($version)"

# TODO: Import modules

# TODO: Update formats

$matchedCommandFile = $null
$matchedCommandNames = @()

$commands = [array](& "$($PSScriptRoot)\Get-AcceleratorCommand.ps1")

if ($command) {
    Write-Verbose "Attempting to match command '$($command)'..."
    $commandObjects = [array]($commands | where {
        if (($_.Name -and $command -eq $_.Name) -or $_.Title -like $command) {
            Write-Verbose "Command '$($_.Title)' ($($_.Name)) matches!"
            return $true
        }
    })

    if ($commandObjects.Count -gt 1) {
        Write-Error "Text '$($command)' matched multiple commands: $(($commandObjects | select -ExpandProperty Title) -join ', ')"
        return
    } elseif ($commandObjects.Count -eq 0) {
        Write-Host ""
        Write-Warning "Unable to find command matching '$($command)'."
        Write-Host ""
    }
}

if (-not($commandObjects) -and $interactive) {
    Write-Host "
To get started, enter the number corresponding to one of the listed commands.

Each command will...

* Provide a description and prompt for confirmation before continuing.
* Prompt for credentials and options along the way as necessary."
}

# Run commands
while ($true) {
    $runCommand = $true

    if ($commandObjects.Count -eq 1) {
        $commandObject = $commandObjects[0]
    } elseif ($interactive) {
        $commandMenu = [array]($commands | Group-Object -Property 'Module' | where {
            ([array]($_.Group)).Count -gt 0
        }| foreach {
            $menuGroup = @{}

            $menuGroup['Name'] = $_.Name

            $menuGroup['Options'] = [array]($_.Group | sort {
                if ($_.Sequence -is [int]) {
                    $_.Sequence
                } else {
                    [int]::MaxValue
                }
            } | foreach {
                if ($_.DisabledReason) {
                    "~$($_.Title)~"
                } else {
                    $_.Title
                }
            })

            return $menuGroup
        })

        if ($commandMenu.Count -eq 0) {
            throw "No available commands."
        }

        $option = & "$($PSScriptRoot)\Read-Option.ps1" -optionGroups $commandMenu -requireSelection $false -allowSelectByName $false

        if (-not $option) {
            break
        }

        if ($option -match '^~.*~$') {
            $commandTitle = $option.Substring(1, $option.Length - 2)
        } else {
            $commandTitle = $option
        }

        $commandObjects = [array]($commands | where {
            if ($_.Title -eq $commandTitle) {
                Write-Verbose "Command '$($_.Title)' ($($_.Name)) matches!"
                return $true
            }
        })

        if ($option -match '^~.*~$') {
            Write-Warning "Command '$($command.Title)' $($command.DisabledReason)."
            if (-not(Read-Confirmation "Continue anyway?")) {
                Write-Host ""
                Write-Host "Select a different command?"
                Write-Host ""
                continue
            }
        }

        $commandObject = $commandObjects[0]

        if (-not(Test-Path $commandObject.Path)) {
            throw "File '$($commandObject.Path)' doesn't exist."
        }

        Write-Host "`r`n$($commandObject.Title)`r`n$('-' * ($commandObject.Title.Length))`r`n`r`n$($commandObject.Steps)`r`n"

	    if ((Read-Host "Continue (y/n)") -ne 'y') {
            Write-Host ""
            Write-Host "Command aborted."
            Write-Host ""
            $runCommand = $false
        }
    } else {
        throw "Command '$($command)' couldn't to be found."
    }

    if ($runCommand) {
        if ($useStart) {
            $tmpPath = "$([System.IO.Path]::GetTempFileName()).xml"
            Write-Host "Writing parameters to file '$($tmpPath)'..."
            $parameterHash | Export-Clixml -Path $tmpPath
        }

        if ($interactive) {
            Write-Host ""
        }

        Write-Host "Running command '$($commandObject.Title)'..."

        if ($interactive) {
            Write-Host ""
        }

        # if (-not($interactive)) {
        #     Write-Progress -Activity "Command '$($commandObject.Title)'" -Status 'Running command...' -PercentComplete 30
        # }

        try {
            if ($useStart) {
                $commandString = "
                    `$here = '$($PSScriptRoot)' ;
                    `$parameterHash = Import-Clixml -Path '$($tmpPath)' ;
                    `$commandPath = '$($commandObject.Path)' ;
                    pushd '$($PWD.Path)' ;
                    `$ErrorActionPreference = 'Stop' ;
                    `$InformationPreference = 'Continue' ;
                    `$PSScriptRoot = Split-Path $commandPath -Parent ;
                    & `$commandPath @parameterHash ;
                "

                $arguments = ""
                $arguments += " -NoProfile"
                $arguments += " -ExecutionPolicy Bypass"
                $arguments += " -Command ""$($commandString)"""
                #Write-Host "PS> $commandString"
                Start-Process -FilePath 'powershell' -ArgumentList $arguments
            } else {
                try {
                    pushd (Split-Path $commandObject.Path -Parent)
                    if ($setPSScriptRoot) {
                        $PSScriptRoot = Split-Path $commandObject.Path -Parent
                    }
                    & $commandObject.Path @parameterHash
                } finally {
                    if ($setPSScriptRoot) {
                        $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
                    }
                }
            }
        #} catch {
        #    Write-Host ""
        #    Write-Error "Error: $($_.Exception.Message)"
        } finally {
            popd
        }

        Write-Host ""
    }

    if (($command -and $commandObject) -or -not($interactive)) {
        break
    }

    $commandObjects = $null

    if (-not(Read-Confirmation "Would you like to run another command?")) {
        break
    }
}
