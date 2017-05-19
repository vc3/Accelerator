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
