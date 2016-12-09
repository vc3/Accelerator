$packageName = $env:chocolateyPackageName
$packagePath = $env:chocolateyPackageFolder
$packageVersion = $env:chocolateyPackageVersion

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

"$($packageVersion)" | Out-File "$($packagePath)\content\Accelerator.version" -Encoding UTF8 -Force

if (-not(Test-Path "$($packageFolder)\content\Accelerator.cfg")) {
    "" | Out-File "$($packageFolder)\content\Accelerator.cfg" -Encoding UTF8
}

if (-not(Test-Path "$($packageFolder)\bin")) {
    New-Item "$($packageFolder)\bin" -Type Directory | Out-Null
}

"@echo off`r`n@powershell -NoProfile -ExecutionPolicy Bypass -Command `"& '%~dp0\..\content\Accelerator.ps1' %*`"`r`n" | `
    Out-File "$($packagePath)\bin\Accelerator.bat" -Encoding ASCII -Force

$batFile = "$packagePath\bin\Accelerator.bat"

if ($env:ChocolateyInstall) {
    $exeFile = Join-Path $env:ChocolateyInstall 'bin\Accelerator.exe'
} else {
    $exeFile = 'C:\ProgramData\chocolatey\bin\Accelerator.exe'
}

$shortcutFile = "$($env:USERPROFILE)\Desktop\Accelerator.lnk"

$iconFile = "$packagePath\content\Accelerator.ico"

# Create shortcuts
Install-BinFile -Name Accelerator -Path $batFile
Install-ChocolateyShortcut `
    -ShortcutFilePath $shortcutFile `
    -Arguments "-Interactive" `
    -TargetPath $exeFile `
    -WorkingDirectory $env:USERPROFILE `
    -IconLocation $iconFile

if (Get-EventLog -LogName 'Application' -Source 'Accelerator' -Newest 1 -ErrorAction SilentlyContinue) {
    Write-Host "Event log source 'Accelerator' is already registered."
} else {
    Write-Host "Attempting to register event log source 'Accelerator'..."
    New-EventLog -LogName 'Application' -Source 'Accelerator' -ErrorAction SilentlyContinue | Out-Null
    Write-EventLog -LogName 'Application' -Source 'Accelerator' -EntryType Information -EventId 0 -Message "Registered event log source 'Accelerator'." -Category 0 | Out-Null
    $evt = Get-EventLog -LogName 'Application' -Source 'Accelerator' -Newest 1 -ErrorAction SilentlyContinue
    if (-not($evt)) {
        Write-Error "Didn't find any events for source 'Accelerator'."
    } else {
        Write-Host $evt.Message
    }
}
