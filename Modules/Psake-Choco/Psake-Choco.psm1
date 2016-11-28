Import-Module "$PSScriptRoot\Modules\ShellOut\ShellOut.psd1"
Import-Module "$PSScriptRoot\Modules\PSData\PSData.psd1"

function Get-ChocoLatestVersion {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$PackageId,

        [string]$Source
    )

    Write-Verbose "Running command ``Get-ChocoLatestVersion -PackageId '$($PackageId)'``..."

    if ($chocoFile) {
        $choco = $chocoFile
    } else {
        $choco = 'C:\ProgramData\chocolatey\choco.exe'
    }

    $listOutputExpr = '^' + [System.Text.RegularExpressions.Regex]::Escape($PackageId) + '\|(.*)$'

    $listArguments = "list $PackageId --limit-output"
    if ($Source) {
        $listArguments += " -Source ""$($Source)"""
    }

    Write-Verbose "Running ``choco $($listArguments)``..."
    $listOutput = (Invoke-Application $choco -Arguments $listArguments -EnsureSuccess $true -ReturnType 'Output') -replace "`r`n", ' '

    Write-Verbose "Output:"
    Write-Verbose $listOutput

    if ($listOutput -match $listOutputExpr) {
        Write-Verbose "Output matches list output expression."
        return [Version]::Parse(($listOutput -replace $listOutputExpr, '$1'))
    } else {
        Write-Verbose "Output did not match any expected format."
        Write-Error "Could not determine latest version of package '$($PackageId)'."
    }
}

function New-ChocoPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$NuspecFile,

        [Parameter(Mandatory = $false, Position = 1)]
        [System.Version]$Version,

        [switch]$Force
    )

    Write-Verbose "Running command ``New-ChocoPackage -NuspecFile '$($NuspecFile)'``..."

    if ($chocoFile) {
        $choco = $chocoFile
    } else {
        $choco = 'C:\ProgramData\chocolatey\choco.exe'
    }

    if (-not(Test-Path $NuspecFile)) {
        Write-Error "Nuspec '$($NuspecFile)' does not exist."
        return
    }

    if ([System.IO.Path]::GetExtension($NuspecFile) -ne '.nuspec') {
        Write-Error "Path '$($NuspecFile)' is not a '.nuspec' file."
        return
    }

    $pkgXml = [xml](Get-Content $NuspecFile)
    $pkgId = $pkgXml.package.metadata.id

    if ($Version) {
        $pkgVersion = $Version.ToString()
    } elseif ($pkgXml.package.metadata.version -eq '$version$') {
        Write-Error "Version must be specified for package '$($pkgId)'."
        return
    } else {
        try {
            $pkgVersion = [Version]::Parse($pkgXml.package.metadata.version)
        } catch {
            Write-Error "Unable to parse version text '$($pkgXml.package.metadata.version)'."
            return
        }
    }

    $expectedPackageFile = Join-Path (Split-Path $NuspecFile -Parent) "$($pkgId).$($pkgVersion).nupkg"
    if (Test-Path $expectedPackageFile) {
        if ($Force.IsPresent) {
            Write-Verbose "Deleting existing package file '$($expectedPackageFile)'..."
            Remove-Item $expectedPackageFile -Force | Out-Null
        } else {
            Write-Error "Package '$($expectedPackageFile)' already exists."
            return
        }
    }

    try {
        Push-Location

        $nuspecDir = Split-Path $NuspecFile -Parent
        Write-Verbose "Moving into '$($nuspecDir)'..."
        Set-Location $nuspecDir

        $cpackArgs = "pack ""$($NuspecFile)"""
        if ($Version) {
            $cpackArgs += " --version $($Version)"
        }

        Write-Verbose "Running ``choco $($cpackArgs)``..."
        Invoke-Application $choco -Arguments $cpackArgs -EnsureSuccess $true -ReturnType 'Output' | Out-Null

        if (Test-Path $expectedPackageFile) {
            Write-Output $expectedPackageFile
        } else {
            Write-Error "Package '$($expectedPackageFile)' was not created."
            return
        }
    } finally {
        Pop-Location
    }
}

function Push-ChocoPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$PackageFile,

        [string]$Source,

        [string]$ApiKey
    )

    Write-Verbose "Running command ``Push-ChocoPackage -PackageFile '$($PackageFile)'``..."

    if ($chocoFile) {
        $choco = $chocoFile
    } else {
        $choco = 'C:\ProgramData\chocolatey\choco.exe'
    }

    if (-not(Test-Path $PackageFile)) {
        Write-Error "Package '$($PackageFile)' does not exist."
        return
    }

    if ([System.IO.Path]::GetExtension($PackageFile) -ne '.nupkg') {
        Write-Error "Path '$($PackageFile)' is not a '.nupkg' file."
        return
    }

    if (-not($Source)) {
        Write-Error "Source is required to push."
        return
    }

    $pushArguments = "push ""$($PackageFile)"" -Source ""$($Source)"""
    if ($ApiKey) {
        $pushArguments += " --api-key $($ApiKey)"
    }

    Write-Verbose "Running ``choco $($pushArguments)``..."

    $pushOutput = Invoke-Application $choco -Arguments $pushArguments -EnsureSuccess $true -ReturnType 'Output'

    Write-Verbose "Output:"
    Write-Verbose $pushOutput
}
