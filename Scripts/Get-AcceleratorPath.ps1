[CmdletBinding()]
param(
    [switch]$AsString
)

if (-not($PSScriptRoot)) {
    $PSScriptRoot = Split-Path $script:MyInvocation.MyCommand.Path
}

Import-Module "$($PSScriptRoot)\..\Modules\Environment\Environment.psd1"

if ((Get-EnvironmentPath -Name 'AcceleratorPath' -AsString) -eq (Get-EnvironmentPath -Name 'AcceleratorPath' -Persisted -AsString)) {
    Write-Verbose "Persisted 'AcceleratorPath' matches current."

    $userPath = Split-Path $PROFILE -Parent

    $userValue = [Environment]::GetEnvironmentVariable('AcceleratorPath', 'User')
    if ($userValue) {
        $userItems = $userValue.Split(@(';'), 'RemoveEmptyEntries')
    } else {
        $userItems = @()
    }

    if (-not($userItems -contains $userPath)) {
        Write-Verbose "Auto-adding the user's profile folder to the accelerator path..."
        $env:AcceleratorPath = $userPath + ";" + $env:AcceleratorPath
    }
}

Write-Verbose "AcceleratorPath=$($env:AcceleratorPath)"

return (Get-EnvironmentPath -Name 'AcceleratorPath' -AsString:$AsString.IsPresent)
