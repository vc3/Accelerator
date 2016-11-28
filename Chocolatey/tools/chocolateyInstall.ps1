$packageName = $env:chocolateyPackageName
$packagePath = $env:chocolateyPackageFolder
$packageVersion = $env:chocolateyPackageVersion

"$($packageVersion)" | Out-File "$($packagePath)\content\Accelerator.version" -Encoding UTF8 -Force

$batFile = "$packagePath\content\Accelerator.bat"

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
