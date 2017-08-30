Import-Module "$PSScriptRoot\Modules\ShellOut\ShellOut.psd1"

Import-Module "$PSScriptRoot\Modules\PSData\PSData.psd1"

function New-ChocoPackage {
	[CmdletBinding()]
	param(
	    [Parameter(Mandatory = $true, Position = 0)]
	    [string]$NuspecFile,
	
	    [Parameter(Mandatory = $false, Position = 1)]
	    [string]$Version,
	
	    [switch]$Force
	)
	
	
	Write-Verbose "Running command ``New-ChocoPackage -NuspecFile '$($NuspecFile)'$(if($Version){' -Version '''+$Version+''''})``..."
	
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
	    $pkgVersion = $Version
	} elseif ($pkgXml.package.metadata.version -eq '$version$') {
	    Write-Error "Version must be specified for package '$($pkgId)'."
	    return
	} else {
	    $pkgVersionText = $pkgXml.package.metadata.version
	    try {
	        # Ensure that the version is a valid version number
	        if ($pkgVersionText -match '-') {
	            $pkgVersion = [System.Version]::Parse($pkgVersionText.Substring(0, $pkgVersionText.IndexOf('-')))
	            $pkgPrereleaseFlag = $pkgVersionText.Substring($pkgVersionText.IndexOf('-') + 1)
	        } else {
	            $pkgVersion = [Version]::Parse($pkgXml.package.metadata.version)
	            $pkgPrereleaseFlag = $null
	        }
	
	        # Re-append pre-release flag
	        $pkgVersionText = $pkgVersion.ToString()
	        if ($pkgPrereleaseFlag) {
	            $pkgVersionText += "-$($pkgPrereleaseFlag)"
	        }
	
	        $pkgVersion = $pkgVersionText
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

function ConvertTo-Version {
	[CmdletBinding()]
	param(
	    [Alias('Text')]
	    [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
	    [string[]]$InputObject
	)
	
	process {
	    foreach ($text in $InputObject) {
	        try {
	            $version = [System.Version]::Parse($text)
	            Write-Output $version
	        } catch {
	            Write-Error "Unable to parse version text '$($text)'."
	        }
	    }
	}
}

function Get-ChocoAllVersions {
	[CmdletBinding()]
	param(
	    [Parameter(Mandatory = $true, Position = 0)]
	    [string]$PackageId,
	
	    [string]$Source,
	
	    [Alias('Pre')]
	    [switch]$PreRelease
	)
	
	
	Write-Verbose "Running command ``Get-ChocoAllVersions -PackageId '$($PackageId)'``..."
	
	if ($chocoFile) {
	    $choco = $chocoFile
	} else {
	    $choco = 'C:\ProgramData\chocolatey\choco.exe'
	}
	
	$listOutputExpr = "^(?:$([System.Text.RegularExpressions.Regex]::Escape($PackageId))\|(.*))`$"
	
	$listArguments = "list $PackageId --limit-output --all"
	if ($PreRelease.IsPresent) {
	    $listArguments += " -pre"
	}
	if ($Source) {
	    $listArguments += " -Source ""$($Source)"""
	}
	
	Write-Verbose "Running ``choco $($listArguments)``..."
	$listOutput = Invoke-Application $choco -Arguments $listArguments -EnsureSuccess $true -ReturnType 'Output'
	
	Write-Verbose "Output:"
	Write-Verbose $listOutput
	
	$allVersions = [array](($listOutput -split "`r`n") | foreach {
	    if ($_ -match $listOutputExpr) {
	        Write-Output ($_ -replace $listOutputExpr, '$1')
	    }
	})
	
	return $allVersions
}

function Get-ChocoLatestVersion {
	[CmdletBinding()]
	param(
	    [Parameter(Mandatory = $true, Position = 0)]
	    [string]$PackageId,
	
	    [string]$Source,
	
	    [Alias('Pre')]
	    [switch]$PreRelease,
	
	    [switch]$AsObject
	)
	
	
	Write-Verbose "Running command ``Get-ChocoLatestVersion -PackageId '$($PackageId)'$(if($AsObject.IsPresent){'-AsObject'})``..."
	
	if ($chocoFile) {
	    $choco = $chocoFile
	} else {
	    $choco = 'C:\ProgramData\chocolatey\choco.exe'
	}
	
	$listOutputExpr = "^(?:$([System.Text.RegularExpressions.Regex]::Escape($PackageId))\|(.*))`$"
	
	$listArguments = "list $PackageId --limit-output"
	if ($PreRelease.IsPresent) {
	    $listArguments += " -pre"
	}
	if ($Source) {
	    $listArguments += " -Source ""$($Source)"""
	}
	
	Write-Verbose "Running ``choco $($listArguments)``..."
	$listOutput = Invoke-Application $choco -Arguments $listArguments -EnsureSuccess $true -ReturnType 'Output'
	
	Write-Verbose "Output:"
	Write-Verbose $listOutput
	
	$latestVersionText = $null
	
	($listOutput -split "`r`n") | foreach {
	    if ($_ -match $listOutputExpr) {
	        Write-Verbose "Output matches list output expression."
	        $latestVersionText = $_ -replace $listOutputExpr, '$1'
	    }
	}
	
	if (-not($latestVersionText)) {
	    Write-Verbose "Output did not match any expected format."
	    Write-Error "Could not determine latest version of package '$($PackageId)'."
	}
	
	if ($AsObject.IsPresent) {
	    return ([Version]::Parse($latestVersionText))
	} else {
	    return $latestVersionText
	}
}

Export-ModuleMember -Function ConvertTo-Version
Export-ModuleMember -Function Get-ChocoAllVersions
Export-ModuleMember -Function Get-ChocoLatestVersion
Export-ModuleMember -Function New-ChocoPackage
Export-ModuleMember -Function Push-ChocoPackage
