$PSModuleAutoloadingPreference = 'None'

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

$here = Split-Path $script:MyInvocation.MyCommand.Path -Parent

$positionalArgs = @('CommandName')

Write-Verbose "Parsing unbound arguments..."
$parsedArgs = $Args | ConvertTo-ParameterHash -PositionalParameters $positionalArgs -ErrorAction Stop

Write-Verbose "Args:`r`n$(($parsedArgs.Keys | foreach { (' ' * 11) + (ConvertTo-RightPaddedString $_ 20) + '=' + $parsedArgs[$_] }) -join "`r`n")"

$parameters = @{}

$commandParameters = @{}

$parameters['CommandParameters'] = $commandParameters

$parameters['UnboundParameters'] = $parsedArgs

if ($parsedArgs.ContainsKey('CommandName')) {
    $parameters['CommandName'] = $parsedArgs['CommandName']
    $parsedArgs.Remove('CommandName') | Out-Null
}

if ($parsedArgs.ContainsKey('y')) {
    $parameters['Confirm'] = $parsedArgs['y']
    $parsedArgs.Remove('Y') | Out-Null
} elseif ($parsedArgs.ContainsKey('yes')) {
    $parameters['Confirm'] = $parsedArgs['yes']
    $parsedArgs.Remove('Yes') | Out-Null
} elseif ($parsedArgs.ContainsKey('confirm')) {
    $parameters['Confirm'] = $parsedArgs['confirm']
    $parsedArgs.Remove('Confirm') | Out-Null
}

if ($parsedArgs.ContainsKey('Verbose')) {
    $parameters['Verbose'] = $parsedArgs['Verbose']
    $parsedArgs.Remove('Verbose') | Out-Null
} elseif ($parsedArgs.ContainsKey('v')) {
    $parameters['Verbose'] = $parsedArgs['v']
    $parsedArgs.Remove('v') | Out-Null
}

if ($parsedArgs.ContainsKey('WorkingDirectory')) {
    $parameters['WorkingDirectory'] = $parsedArgs['WorkingDirectory']
    $parsedArgs.Remove('WorkingDirectory') | Out-Null
} else {
    $parameters['WorkingDirectory'] = (Get-Location).Path
}

if ($parsedArgs.ContainsKey('Interactive')) {
    $parameters['Interactive'] = $parsedArgs['Interactive']
    $parsedArgs.Remove('Interactive') | Out-Null
}

$useStart = $false
if ($parsedArgs.ContainsKey('UseStart')) {
    $useStart = $parsedArgs['UseStart']
    $parsedArgs.Remove('UseStart') | Out-Null
}

$windowTitle = 'Accelerator'
if ($parsedArgs.ContainsKey('WindowTitle')) {
    $windowTitle = $parsedArgs['WindowTitle']
    $parsedArgs.Remove('WindowTitle') | Out-Null
}

$powershellVersion = $powershellVersion
if ($parsedArgs.ContainsKey('PowerShellVersion')) {
    $powershellVersion = $parsedArgs['PowerShellVersion']
    $parsedArgs.Remove('PowerShellVersion') | Out-Null
}

$host.ui.RawUI.WindowTitle = $windowTitle

if ($useStart) {
    $tmpPath = "$([System.IO.Path]::GetTempFileName()).xml"

    Write-Host "Writing parameters to file '$($tmpPath)'..."
    $parameters | Export-Clixml -Path $tmpPath

    $commandString = "
        try {
            `$ErrorActionPreference = 'Stop' ;
            `$host.ui.RawUI.WindowTitle = '$($windowTitle)' ;
            Set-Location '$($PWD.Path)' ;
            Import-Module '$($here)\Accelerator.psd1' ;
            `$parameters = Import-Clixml -Path '$($tmpPath)' ;
            Start-Accelerator @parameters ;
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

    Import-Module "$($here)\Accelerator.psd1"
    Start-Accelerator @parameters
}
