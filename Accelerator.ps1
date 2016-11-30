$PSModuleAutoloadingPreference = 'None'

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

$here = Split-Path $script:MyInvocation.MyCommand.Path -Parent

$positionalArgs = @('CommandName')

Write-Verbose "Parsing unbound arguments..."
$parsedArgs = $Args | & "$($here)\Scripts\ConvertTo-ParameterHash.ps1" -PositionalParameters $positionalArgs -ErrorAction Stop

Write-Verbose "Args:`r`n$(($parsedArgs.Keys | foreach { (' ' * 11) + $_ + '=' + $parsedArgs[$_] }) -join "`r`n")"

$parameters = @{}

$parameters['CommandParameters'] = $parsedArgs

if ($parsedArgs.ContainsKey('CommandName')) {
    $parameters['CommandName'] = $parsedArgs['CommandName']
    $parsedArgs.Remove('CommandName') | Out-Null
}

& "$($here)\Scripts\Move-HashtableKey.ps1" -Source $parsedArgs -SourceKeys 'y','yes','Confirm' -Target $parameters -TargetKey 'Confirm'
& "$($here)\Scripts\Move-HashtableKey.ps1" -Source $parsedArgs -SourceKeys 'Verbose','v' -Target $parameters -TargetKey 'Verbose'
& "$($here)\Scripts\Move-HashtableKey.ps1" -Source $parsedArgs -SourceKeys 'WorkingDirectory' -Target $parameters -TargetKey 'WorkingDirectory' -DefaultValue "$((Get-Location).Path)"
& "$($here)\Scripts\Move-HashtableKey.ps1" -Source $parsedArgs -SourceKeys 'Interactive' -Target $parameters -TargetKey 'Interactive'

$useStart = $parsedArgs | & "$($here)\Scripts\Extract-HashtableKey.ps1" -Keys 'UseStart' -DefaultValue $false
$windowTitle = $parsedArgs | & "$($here)\Scripts\Extract-HashtableKey.ps1" -Keys 'WindowTitle' -DefaultValue 'Accelerator'
$powershellVersion = $parsedArgs | & "$($here)\Scripts\Extract-HashtableKey.ps1" -Keys 'PowerShellVersion'

$host.ui.RawUI.WindowTitle = $windowTitle

if ($useStart) {
    $tmpPath = "$([System.IO.Path]::GetTempFileName()).xml"

    Write-Host "Writing parameters to file '$($tmpPath)'..."
    $parameters | Export-Clixml -Path $tmpPath

    $commandString = "
        try {
            `$ErrorActionPreference = 'Stop' ;
            `$InformationPreference = 'Continue' ;
            `$host.ui.RawUI.WindowTitle = '$($windowTitle)' ;
            `$global:PSModulesRoot = '$($PSModulesRoot)' ;
            Set-Location '$($PWD.Path)' ;
            `$parameters = Import-Clixml -Path '$($tmpPath)' ;
            & '$($here)\Scripts\Start-Accelerator.ps1' @parameters ;
        } catch {
            `$e = `$_.Exception

            do {
                Write-Host `$e.Message -ForegroundColor Red
                Write-Host `$e.StackTrace -ForegroundColor Red

                `$e = `$_.Exception.InnerException
            } while (`$e)

            Read-Host 'Press any key to continue...'
        }
    "

    $arguments = ""

    if ($powershellVersion) {
        $arguments += " -Version $($powershellVersion)"
    }

    $arguments += " -NoProfile"
    $arguments += " -ExecutionPolicy Bypass"
    $arguments += " -Command ""$($commandString)"""

    Write-Host "Starting Accelerator in a new process..."
    Start-Process -FilePath 'powershell' -ArgumentList $arguments
} else {
    if ($powershellVersion) {
        Write-Error "Can't force a particular PowerShell version unless the '-UseStart' flag is used."
        return
    }

    & "$($here)\Scripts\Start-Accelerator.ps1" @parameters
}
