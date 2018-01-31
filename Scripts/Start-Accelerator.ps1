[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [string]$CommandName,

    [switch]$Interactive,

    [string]$WorkingDirectory,

    [Alias('y')]
    [Alias('yes')]
    [switch]$SkipConfirmation,

    [Alias('LogFile')]
    [string]$LogFilePath,

    [Hashtable]$CommandParameters
)

$PSModuleAutoloadingPreference = 'None'

$global:ErrorActionPreference = 'Stop'
$global:InformationPreference = 'Continue'

$global:AcceleratorCommandSuccess = $null

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

Import-Module "$($PSScriptRoot)\..\Modules\Accelerator\Accelerator.psd1" -Force

if (-not($CommandName) -and -not($Interactive.IsPresent)) {
    throw "A command must be specified when run in non-interactive mode."
}

if ($Interactive.IsPresent) {
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
}

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

$runCommand = $true

# Run commands
while ($runCommand) {
    if ($commandObjects.Count -eq 1) {
        $commandObject = $commandObjects[0]
    } elseif ($Interactive.IsPresent) {
        $commandMenu = [array]($commands | Group-Object -Property 'Module' | where {
            ([array]($_.Group)).Count -gt 0
        }| foreach {
            $menuGroup = @{}

            $menuGroup['Name'] = $_.Name

            $menuGroup['Options'] = [array]($_.Group | sort {
                if ($_.Sequence -ne $null) {
                    if ($_.Sequence -is [int]) {
                        $_.Sequence
                    } else {
                        Write-Warning "Invalid sequence value '$($_.Sequence)' for command '$($_.Name)'."
                        [int]::MaxValue
                    }
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

        if (-not(Test-Path $commandObject.Path)) {
            throw "File '$($commandObject.Path)' doesn't exist."
        }

        if ($option -match '^~.*~$') {
            Write-Warning "Command '$($commandObject.Title)' $($commandObject.DisabledReason)."
            if ($Interactive.IsPresent) {
                if (-not(Read-Confirmation -Message "Continue anyway?")) {
                    Write-Host ""
                    Write-Host "Select a different command?"
                    Write-Host ""
                    continue
                }
            } else {
                Write-Host ""
                Write-Host "Command aborted."
                Write-Host ""
                $runCommand = $false
            }
        }

        if ($runCommand) {
            Write-Host "`r`n$($commandObject.Title)`r`n$('-' * ($commandObject.Title.Length))`r`n`r`n$($commandObject.Steps)`r`n"

            if (-not($SkipConfirmation.IsPresent) -and -not(Read-Confirmation -Message "Continue")) {
                Write-Host ""
                Write-Host "Command aborted."
                Write-Host ""
                $runCommand = $false
            }
        }
    } else {
        throw "Command '$($CommandName)' couldn't to be found."
    }

    if ($runCommand) {

        if ($commandObject.RunAsAdmin) {
            $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
            $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
            $adminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator
            if (-not($principal.IsInRole($adminRole))) {
                throw "Command '$($commandObject.Title)' requires elevation."
            }
        }

        Write-Verbose "Removing modules not intended to be exposed..."

        if (-not($modulesToKeep -contains 'PowerYaml') -and (Get-Module 'PowerYaml' -ErrorAction SilentlyContinue)) {
            Write-Verbose "Removing module 'PowerYaml'..."
            Remove-Module 'PowerYaml' | Out-Null
        }

        if (-not($modulesToKeep -contains 'Environment') -and (Get-Module 'Environment' -ErrorAction SilentlyContinue)) {
            Write-Verbose "Removing module 'Environment'..."
            Remove-Module 'Environment' | Out-Null
        }

        if ($LogFilePath) {
            "Running command '$($commandObject.Title)' at '$([DateTime]::Now)'..." | Out-File $LogFilePath -Append
        }

        if ($Interactive.IsPresent) {
            Write-Host ""
            Write-Host "Running command '$($commandObject.Title)'..."
            Write-Host ""
        }

        # if (-not($Interactive.IsPresent)) {
        #     Write-Progress -Activity "Command '$($commandObject.Title)'" -Status 'Running command...' -PercentComplete 30
        # }

        $commandSuccess = $false

        try {
            $global:AcceleratorInteractive = $Interactive

            $global:AcceleratorLogFilePath = $LogFilePath

            $global:AcceleratorRoot = Split-Path $PSScriptRoot -Parent

            $global:AcceleratorCommandFileName = $commandObject.Path

            $PSScriptRoot = Split-Path $commandObject.Path -Parent

            # Temporarily set to false to avoid infinite loop if a script
            # calls 'continue' from within an error handler
            $runCommand = $false

            & $commandObject.Path @CommandParameters | ForEach-Object {
                if ($LogFilePath) {
                    $_ |  Out-File $LogFilePath -Append
                }

                Write-Output $_
            }

            $commandSuccess = $true
        } catch {
            if ($LogFilePath) {
                "Error: $($_.Exception.Message)" | Out-File $LogFilePath -Append
                # "$($_.Exception | ConvertTo-Json)" | Out-File $LogFilePath -Append
                if ($_.Exception.StackTrace) {
                    "$($_.Exception.StackTrace)" | Out-File $LogFilePath -Append
                }
            }

            if ($Interactive.IsPresent) {
                Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
                if ($_.Exception.StackTrace) {
                    Write-Host "$($_.Exception.StackTrace)" -ForegroundColor Red
                }
            }

            throw
        } finally {
            if ($LogFilePath) {
                "Command '$($commandObject.Title)' $(if ($commandSuccess) { 'succeeded' } else { 'failed' }) at '$([DateTime]::Now)'." | Out-File $LogFilePath -Append
            }

            if ($Interactive.IsPresent) {
                Write-Host "Command '$($commandObject.Title)' $(if ($commandSuccess) { 'succeeded' } else { 'failed' })."
            }

            $global:AcceleratorCommandSuccess = $commandSuccess

            $global:AcceleratorLogFilePath = $null

            $global:AcceleratorInteractive = $null

            $global:AcceleratorRoot = $null

            $global:AcceleratorCommandFileName = $null

            $PSScriptRoot = Split-Path $script:MyInvocation.MyCommand.Path -Parent
        }

        if ($Interactive.IsPresent) {
            Write-Host ""
        }
    }

    # Reset to true after the script exits properly
    $runCommand = $true
    
    if (($CommandName -and $commandObject) -or -not($Interactive.IsPresent)) {
        break
    }

    $commandObjects = $null

    if (-not(Read-Confirmation -Message "Would you like to run another command?")) {
        break
    }
}

if (-not($runCommand)) {
    Write-Warning "Script exited abnormally, likely due to inappropriate use of the `"continue`" or `"break`" keyword."
}
