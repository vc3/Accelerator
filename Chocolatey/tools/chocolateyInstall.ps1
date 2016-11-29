$packageName = $env:chocolateyPackageName
$packagePath = $env:chocolateyPackageFolder
$packageVersion = $env:chocolateyPackageVersion

"$($packageVersion)" | Out-File "$($packagePath)\content\Accelerator.version" -Encoding UTF8 -Force

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
