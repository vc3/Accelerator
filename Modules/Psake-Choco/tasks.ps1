$psakeChocoRoot = Split-Path $MyInvocation.MyCommand.Path -Parent

$chocoNupkgFileExpr = "^((?:.+(?:[^\d]|(?<=[^\d\.])\d)(?=\.))+)\.((\d+(?=\.)(?:\.\d+)+)(\-[A-Za-z]+)?)\.nupkg$"

task ListChocoPackages {
    if ($chocoOutDir) {
        $searchRootDir = $chocoOutDir
    } else {
        $searchRootDir = Join-Path (Split-Path (Split-Path $psakeChocoRoot)) 'Chocolatey'
    }

	Write-Message "Searching for packages in '$($searchRootDir)'..."
	Get-ChildItem $searchRootDir -Filter *.nupkg | Group-Object {
        $_.Name -replace $chocoNupkgFileExpr, '$1'
    } | ForEach-Object {
		Write-Message "Found package '$($_.Name)':"
        $_.Group | ForEach-Object {
    		Write-Host "             - v$($_.Name -replace $chocoNupkgFileExpr, '$2')"
        }
	}
}

task BuildChocoPackages {
    if (-not($chocoSource)) {
        throw "Define property ```$chocoSource`` in order to deploy packages."
    }

    if (-not($chocoApiKey)) {
        throw "Define property ```$chocoApiKey`` in order to deploy packages."
    }

    if($chocoSource -eq "chocolatey") {
        throw "TODO: Implement support for Chocolatey.org"
    } elseif ($chocoSource -match "\\\\.+") {
        $chocoPullSource = $chocoSource
    } else { #assume MyGet
        $chocoPullSource = "https://www.myget.org/F/$chocoSource/auth/$chocoApiKey"
    }

    if ($chocoPkgsDir) {
        $searchRootDir = $chocoPkgsDir
    } else {
        $searchRootDir = Join-Path (Split-Path (Split-Path $psakeChocoRoot)) 'Chocolatey'
    }

    if (Test-Path $searchRootDir) {
        Write-Message "Building choco packages in '$($searchRootDir)'..."
        Get-ChildItem $searchRootDir -Filter *.nuspec -Recurse | ForEach-Object {
            Write-Message "Found '$($_.FullName)'..."
            $pkgFolder = Split-Path $_.FullName -Parent
            $pkgId = [System.IO.Path]::GetFileNameWithoutExtension((Split-Path $_.FullName -Leaf))
            $pkgXml = [xml](Get-Content $_.FullName)
            if ($pkgXml.package.metadata.version -eq '$version$') {
                if (Test-Path (Join-Path $pkgFolder "$($pkgId).version")) {
                    $pkgLocalVersion = [Version]::Parse((Get-Content (Join-Path $pkgFolder "$($pkgId).version")).Trim())
                } elseif ($root -and $root -ne $pkgFolder -and (Test-Path (Join-Path $root "$($pkgId).version"))) {
                    $pkgLocalVersion = [Version]::Parse((Get-Content (Join-Path $root "$($pkgId).version")).Trim())
                } elseif (Test-Path (Join-Path $pkgFolder "$($pkgId).psd1")) {
                    $pkgModuleManifest = Import-PSData (Join-Path $pkgFolder "$($pkgId).psd1")
                    $pkgLocalVersion = [Version]::Parse($pkgModuleManifest.ModuleVersion)
                } elseif ($root -and $root -ne $pkgFolder -and (Test-Path (Join-Path $root "$($pkgId).psd1"))) {
                    $pkgModuleManifest = Import-PSData (Join-Path $root "$($pkgId).psd1")
                    $pkgLocalVersion = [Version]::Parse($pkgModuleManifest.ModuleVersion)
                } else {
                    Write-Error "Cannot determine local version of package '$($pkgId)'."
                    return
                }
            } else {
                try {
                    $pkgLocalVersion = [Version]::Parse($pkgXml.package.metadata.version)
                } catch {
                    Write-Error "Unable to parse version text '$($pkgXml.package.metadata.version)'."
                    return
                }
            }
            Write-Message "Local version of '$($pkgId)' is v$($pkgLocalVersion)."
            Write-Message "Attempting to find latest version of '$($pkgId)'..."
            $pkgLatestVersion = Get-ChocoLatestVersion -PackageId $pkgId -Source $chocoPullSource -ErrorAction SilentlyContinue
            if ($pkgLatestVersion) {
                Write-Message "Latest version of '$($pkgId)' is v$($pkgLatestVersion)."
                if ($pkgLocalVersion -eq $pkgLatestVersion) {
                    Write-Message "No update to package - not building."
                    $shouldBuild = $false
                } elseif ($pkgLocalVersion -lt $pkgLatestVersion) {
                    Write-Message "Local package is older - not building."
                    $shouldBuild = $false
                } else {
                    Write-Message "Package local version is newer - building..."
                    $shouldBuild = $true
                }
            } else {
                $shouldBuild = $true
                Write-Message "Package '$($pkgId)' was not found - building..."
            }
            if ($shouldBuild) {
                Write-Message "Running pack command on '$($_.FullName)'..."

                $pkgFile = New-ChocoPackage -NuspecFile $_.FullName -Version $pkgLocalVersion -Force
                Write-Message "Created package file '$($pkgFile)'."
                if ($chocoOutDir) {
                    $pkgDest = $chocoOutDir
                } else {
                    $pkgDest = Split-Path (Split-Path $psakeChocoRoot -Parent) -Parent
                }
                Write-Message "Moving package file '$(Split-Path $pkgFile -Leaf)' to '$($pkgDest)'..."
                Move-Item $pkgFile $pkgDest -Force | Out-Null
            }
        }
    } else {
        Write-Message "Search root `chocoPkgsDir='$($searchRootDir)'` does not exist."
    }
}

task DeployChocoPackages {
    if (-not($chocoSource)) {
        throw "Define property ```$chocoSource`` in order to deploy packages."
    }

    if (-not($chocoApiKey)) {
        throw "Define property ```$chocoApiKey`` in order to deploy packages."
    }

    if($chocoSource -eq "chocolatey") {
        throw "TODO: Implement support for Chocolatey.org"
    } elseif ($chocoSource -match "\\\\.+") {
        $chocoPullSource = $chocoSource
        $chocoPushSource = $chocoSource
    } else { #assume MyGet
        $chocoPullSource = "https://www.myget.org/F/$chocoSource/auth/$chocoApiKey"
        $chocoPushSource = "https://www.myget.org/F/$chocoSource/api/v2/"
    }

    if ($chocoOutDir) {
        $searchRootDir = $chocoOutDir
    } else {
        $searchRootDir = Join-Path (Split-Path (Split-Path $psakeChocoRoot)) 'Chocolatey'
    }

	Write-Message "Searching for packages in '$($searchRootDir)'..."
	Get-ChildItem $searchRootDir -Filter *.nupkg | Group-Object {
        $_.Name -replace $chocoNupkgFileExpr, '$1'
    } | ForEach-Object {
		Write-Message "Found package '$($_.Name)':"
        Write-Message "Attempting to find latest version of '$($_.Name)'..."
        $pkgLatestVersion = Get-ChocoLatestVersion -PackageId $_.Name -Source $chocoPullSource -ErrorAction SilentlyContinue
        if ($pkgLatestVersion) {
            Write-Message "Latest version of '$($_.Name)' is v$($pkgLatestVersion)."
        } else {
            Write-Message "Package '$($_.Name)' was not found."
        }
        $_.Group | ForEach-Object {
            Write-Host "             - " -NoNewLine
            $pkgVersion = [System.Version]::Parse(($_.Name -replace $chocoNupkgFileExpr, '$3'))
            if ($pkgLatestVersion -and $pkgVersion -le $pkgLatestVersion) {
                Write-Host "v$($_.Name -replace $chocoNupkgFileExpr, '$2')" -ForegroundColor DarkGray
            } else {
                Write-Host "v$($_.Name -replace $chocoNupkgFileExpr, '$2')" -ForegroundColor Cyan
                Write-Message "Pushing '$($_.Name)' to $($chocoPushSource)..."
                Push-ChocoPackage -PackageFile $_.FullName -Source $chocoPushSource -ApiKey $chocoApiKey
                Write-Message "Push was successful!"
            }
        }
	}
}
