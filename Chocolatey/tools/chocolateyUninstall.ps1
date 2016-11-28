
$packageName = $env:chocolateyPackageName
$packagePath = $env:chocolateyPackageFolder

# Cleanup
Uninstall-BinFile -Name Accelerator -Path "$packagePath\content\Accelerator.bat"
