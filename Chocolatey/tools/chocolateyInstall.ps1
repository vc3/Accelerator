[CmdletBinding()]
param(
    [string]$PackageFolder = $env:chocolateyPackageFolder,
    [string]$PackageVersion = $env:chocolateyPackageVersion
)

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

. "$($PackageFolder)\tools\Helpers\Test-EventLogSource.ps1"

"$($PackageVersion)" | Out-File "$($PackageFolder)\content\Accelerator.version" -Encoding UTF8 -Force

if (-not(Test-Path "$($packageFolder)\content\Accelerator.cfg")) {
    "" | Out-File "$($packageFolder)\content\Accelerator.cfg" -Encoding UTF8
}

$batFile = "$PackageFolder\content\Accelerator.bat"

Install-BinFile -Name Accelerator -Path $batFile

if (-not(Test-EventLogSource 'Accelerator')) {
    try {
        Write-Host "Creating event log source 'Accelerator'..."
        New-EventLog -LogName 'Application' -Source 'Accelerator' -ErrorAction 'Stop' | Out-Null
    } catch {
        if ($_.Exception -is [InvalidOperationException] -and 'The "Accelerator" source is already registered on the "localhost" computer.') {
            Write-Warning $_.Exception.Message
        } else {
            throw $_.Exception
        }
    }
} else {
    Write-Host "Event log source 'Accelerator' already exist."
}
