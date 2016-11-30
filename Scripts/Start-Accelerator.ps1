[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [string]$CommandName,

    [switch]$Interactive,

    [string]$WorkingDirectory,

    [Alias('y')]
    [Alias('yes')]
    [switch]$Confirm,

    [Hashtable]$CommandParameters,

    [Hashtable]$UnboundParameters
)

if ($UnboundParameters.Keys.Count -gt 0) {
    Write-Warning "Unbound Parameters:`r`n$(($UnboundParameters.Keys | foreach { (' ' * 11) + $_ + '=' + $UnboundParameters[$_] }) -join "`r`n")"
}

$PSModuleAutoloadingPreference = 'None'

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

if (-not($PSScriptRoot) -or $PSScriptRoot -ne (Split-Path $script:MyInvocation.MyCommand.Path -Parent)) {
    Write-Verbose "Setting 'PSScriptRoot' variable since it isn't automatically set by the runtime..."
    $PSScriptRoot = Split-Path $script:MyInvocation.MyCommand.Path -Parent
}

Write-Verbose "PowerShell v$($PSVersionTable.PSVersion)"
Write-Verbose "DotNet v$($PSVersionTable.CLRVersion)"

$modulesToKeep = @()

if (Get-Module 'PowerYaml' -ErrorAction SilentlyContinue) {
    $modulesToKeep += 'PowerYaml'
}

if (Get-Module 'Environment' -ErrorAction SilentlyContinue) {
    $modulesToKeep += 'Environment'
}

Import-Module "$($PSScriptRoot)\..\Modules\Accelerator\Accelerator.psd1"

if (-not($CommandName) -and -not($Interactive.IsPresent)) {
    throw "A command must be specified when run in non-interactive mode."
}

if (Test-Path "$($PSScriptRoot)\..\Accelerator.version") {
    $version = (Get-Content "$($PSScriptRoot)\..\Accelerator.version").Trim()
} else {
    $acceleratorModule = Get-Module 'Accelerator' -ErrorAction SilentlyContinue
    if ($acceleratorModule) {
        $version = "$($acceleratorModule.Version)-dev"
    } else {
        $version = '???'
    }
}

Write-Host "Accelerator v$($version)"
Write-Host ""

$matchedCommandFile = $null
$matchedCommandNames = @()

$commands = [array](& "$($PSScriptRoot)\Get-AcceleratorCommand.ps1")

if ($CommandName) {
    Write-Verbose "Attempting to match command '$($CommandName)'..."
    $commandObjects = [array]($commands | where {
        if (($_.Name -and $CommandName -eq $_.Name) -or $_.Title -like $CommandName) {
            Write-Verbose "Command '$($_.Title)' ($($_.Name)) matches!"
            return $true
        }
    })

    if ($commandObjects.Count -gt 1) {
        Write-Error "Text '$($CommandName)' matched multiple commands: $(($commandObjects | select -ExpandProperty Title) -join ', ')"
        return
    } elseif ($commandObjects.Count -eq 0) {
        Write-Host ""
        Write-Warning "Unable to find command matching '$($CommandName)'."
        Write-Host ""
    }
}

# Run commands
while ($true) {
    $runCommand = $true

    if ($commandObjects.Count -eq 1) {
        $commandObject = $commandObjects[0]
    } elseif ($Interactive.IsPresent) {
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

        $option = & "$($PSScriptRoot)\Read-MenuOption.ps1" -optionGroups $commandMenu -requireSelection $false -allowSelectByName $false

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

        $commandObject = $commandObjects[0]

        if ($option -match '^~.*~$') {
            Write-Warning "Command '$($commandObject.Title)' $($commandObject.DisabledReason)."
            if (-not($Confirm.IsPresent) -and -not(Read-Confirmation -Message "Continue anyway?")) {
                Write-Host ""
                Write-Host "Select a different command?"
                Write-Host ""
                continue
            }
        }

        if (-not(Test-Path $commandObject.Path)) {
            throw "File '$($commandObject.Path)' doesn't exist."
        }

        Write-Host "`r`n$($commandObject.Title)`r`n$('-' * ($commandObject.Title.Length))`r`n`r`n$($commandObject.Steps)`r`n"

	    if (-not($Confirm.IsPresent) -and -not(Read-Confirmation -Message "Continue")) {
            Write-Host ""
            Write-Host "Command aborted."
            Write-Host ""
            $runCommand = $false
        }
    } else {
        throw "Command '$($CommandName)' couldn't to be found."
    }

    if ($runCommand) {

        Write-Verbose "Removing modules not intended to be exposed..."

        if (-not($modulesToKeep -contains 'PowerYaml') -and (Get-Module 'PowerYaml' -ErrorAction SilentlyContinue)) {
            Write-Verbose "Removing module 'PowerYaml'..."
            Remove-Module 'PowerYaml' | Out-Null
        }

        if (-not($modulesToKeep -contains 'Environment') -and (Get-Module 'Environment' -ErrorAction SilentlyContinue)) {
            Write-Verbose "Removing module 'Environment'..."
            Remove-Module 'Environment' | Out-Null
        }

        if ($Interactive.IsPresent) {
            Write-Host ""
        }

        Write-Host "Running command '$($commandObject.Title)'..."
        Write-Host ""

        # if (-not($Interactive.IsPresent)) {
        #     Write-Progress -Activity "Command '$($commandObject.Title)'" -Status 'Running command...' -PercentComplete 30
        # }

        try {
            $PSScriptRoot = Split-Path $commandObject.Path -Parent
            & $commandObject.Path @CommandParameters
        #} catch {
        #    Write-Host ""
        #    Write-Error "Error: $($_.Exception.Message)"
        } finally {
            $PSScriptRoot = Split-Path $script:MyInvocation.MyCommand.Path -Parent
        }

        Write-Host ""
    }

    if (($CommandName -and $commandObject) -or -not($Interactive.IsPresent)) {
        break
    }

    $commandObjects = $null

    if (-not(Read-Confirmation -Message "Would you like to run another command?")) {
        break
    }
}
