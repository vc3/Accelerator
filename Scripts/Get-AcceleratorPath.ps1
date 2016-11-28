[CmdletBinding()]
param(
    [switch]$AsArray
)

$acceleratorPath = $env:AcceleratorPath

if (-not($acceleratorPath)) {
    Write-Verbose "Using default commands path."
    $acceleratorPath = $PSScriptRoot
}

Write-Verbose "AcceleratorPath=$($acceleratorPath)"

if ($AsArray.IsPresent) {
    return [array]($acceleratorPath -split ';')
} else {
    return $acceleratorPath
}
