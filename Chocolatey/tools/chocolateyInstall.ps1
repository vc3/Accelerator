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
    -IconLocation $iconFile `
    -RunAsAdmin

# Taken from Boxstarter
# https://github.com/mwrock/boxstarter/blob/master/BuildScripts/setup.ps1
$tempFile = "$($env:TEMP)\$([guid]::NewGuid().ToString()).lnk"
$writer = new-object System.IO.FileStream $tempFile, ([System.IO.FileMode]::Create)
$reader = new-object System.IO.FileStream $shortcutFile, ([System.IO.FileMode]::Open)
while ($reader.Position -lt $reader.Length)
{
    $byte = $reader.ReadByte()
    if ($reader.Position -eq 22) {
        $byte = 34
    }
    $writer.WriteByte($byte)
}
$reader.Close()
$writer.Close()
Move-Item -Path $tempFile $shortcutFile -Force
