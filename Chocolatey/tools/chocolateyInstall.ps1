$packageName = $env:chocolateyPackageName
$packagePath = $env:chocolateyPackageFolder
$packageVersion = $env:chocolateyPackageVersion

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

"$($packageVersion)" | Out-File "$($packagePath)\content\Accelerator.version" -Encoding UTF8 -Force

if (-not(Test-Path "$($packageFolder)\content\Accelerator.cfg")) {
    "" | Out-File "$($packageFolder)\content\Accelerator.cfg" -Encoding UTF8
}

$batFile = "$packagePath\content\Accelerator.bat"

Install-BinFile -Name Accelerator -Path $batFile

if (-not(Test-EventLog 'Accelerator') -or -not(Test-EventLogSource 'Accelerator')) {
    try {
        Write-Host "Creating event log 'Accelerator' with source 'Accelerator'..."
        New-EventLog -LogName Accelerator -Source Accelerator -ErrorAction 'Stop' | Out-Null
    } catch {
        if ($_.Exception -is [InvalidOperationException] -and 'The "Accelerator" source is already registered on the "localhost" computer.') {
            Write-Warning $_.Exception.Message
        } else {
            throw $_.Exception
        }
    }
} else {
    Write-Host "Event log 'Accelerator' and source 'Accelerator' already exist."
}
