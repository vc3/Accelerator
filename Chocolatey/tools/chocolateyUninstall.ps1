
$packageName = $env:chocolateyPackageName
$packagePath = $env:chocolateyPackageFolder

# Cleanup
Uninstall-BinFile -Name Accelerator -Path "$packagePath\bin\Accelerator.bat"
