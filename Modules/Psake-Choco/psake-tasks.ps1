Write-Verbose "Loading 'Psake-Choco\psake-tasks.ps1'..."

$psakeChocoRoot = Split-Path $MyInvocation.MyCommand.Path -Parent

Import-Module "$($psakeChocoRoot)\Modules\PSData\PSData.psd1"

$chocoNupkgFileExpr = "^((?:.+(?:[^\d]|(?<=[^\d\.])\d)(?=\.))+)\.((\d+(?=\.)(?:\.\d+)+)(\-[A-Za-z]+)?)\.nupkg$"

properties {
    Write-Verbose "Applying properties from 'Psake-Choco\psake-tasks.ps1'..."

    if (-not $chocoApiKey) {
		Write-Warning "Psake property '`$chocoApiKey' must be configured."
	}

    if (-not($chocoOutDir)) {
		Write-Warning "Psake property '`$chocoOutDir' is not defined: defaulting to '.\Chocolatey'."
    }
}

task Choco:Help {
    Write-Host "TODO: Help for 'Psake-Choco' tasks."
}

task Choco:ListPackages {
    if (-not($chocoSource)) {
        throw "Define property ```$chocoSource`` in order to deploy packages."
    }

    if ($chocoSource -match "^\\\\.+" -or $chocoSource -match "^[A-Z]:\\") {
        # Use a UNC path verbatim
        $chocoPullSource = $chocoSource
        $chocoPushSource = $chocoSource
    } else {
        if (-not($chocoApiKey)) {
            throw "Define property ```$chocoApiKey`` in order to deploy packages."
        }

        if ($chocoSource -eq "chocolatey.org") {
            $chocoPullSource = "https://chocolatey.org/api/v2/"
            $chocoPushSource = "https://push.chocolatey.org/"
        } elseif ($chocoSourceHost -eq 'myget') {
            $chocoPullSource = "https://www.myget.org/F/$chocoSource/auth/$chocoApiKey"
            $chocoPushSource = "https://www.myget.org/F/$chocoSource/api/v2/"
        } else {
            throw "Unknown chocolatey source '$($chocoSource)'."
        }
    }

    if ($chocoPkgsDir) {
        $searchRootDir = $chocoPkgsDir
    } else {
        $searchRootDir = Join-Path (Split-Path (Split-Path $psakeChocoRoot)) 'Chocolatey'
    }

    $packageMetadata = @{}

    if (Test-Path $searchRootDir) {
        Write-Message "Searching for nuspecs in '$($searchRootDir)'..."
        Get-ChildItem $searchRootDir -Filter *.nuspec -Recurse | where {
            if ((Test-Path "$($_.FullName).ignore") -or ($chocoIgnoreNuspecs -and $chocoIgnoreNuspecs -contains ([System.IO.Path]::GetFileNameWithoutExtension($_.Name)))) {
                Write-Warning "Ignoring package '$($_.Name)'."
            } else {
                return $true
            }
        } | ForEach-Object {
            Write-Verbose "Found '$($_.FullName)'..."
    		#Write-Host "             .\$($_.FullName.Substring($root.Length + 1))"
            $pkgFolder = Split-Path $_.FullName -Parent
            $pkgSpec = [xml](Get-Content $_.FullName)
            $pkgId = [System.IO.Path]::GetFileNameWithoutExtension((Split-Path $_.FullName -Leaf)).ToLower()
            $packageMetadata[$pkgId] = $pkgSpec.package.metadata
        }

        if ($chocoOutDir) {
            $searchRootDir = $chocoOutDir
        } else {
            $searchRootDir = Join-Path (Split-Path (Split-Path $psakeChocoRoot)) 'Chocolatey'
        }

    	Write-Message "Searching for packages in '$($searchRootDir)'..."
    	Get-ChildItem $searchRootDir -Filter *.nupkg | where {
            $pkgId = $_.Name -replace $chocoNupkgFileExpr, '$1'
            return $packageMetadata.Keys -contains $pkgId
        } | Group-Object {
            $_.Name -replace $chocoNupkgFileExpr, '$1'
        } | ForEach-Object {
    		Write-Verbose "Found package '$($_.Name)' v$($packageMetadata[$_.Name].version):"
            Write-Verbose "Attempting to find latest version of '$($_.Name)'..."
            $pkgLatestVersion = Get-ChocoLatestVersion -PackageId $_.Name -Source $chocoPullSource -Pre -ErrorAction SilentlyContinue
            $pkgVersions = Get-ChocoAllVersions -PackageId $_.Name -Source $chocoPullSource -Pre -ErrorAction SilentlyContinue
            if ($pkgVersions) {
                Write-Verbose "All versions of '$($_.Name)': $($pkgVersions -join ', ')."
            } else {
                Write-Verbose "Package '$($_.Name)' was not found."
            }
            Write-Host "             Found '$($_.Name)' (nuspec=$($packageMetadata[$_.Name].version);deployed=$($pkgLatestVersion)):"
            $_.Group | ForEach-Object {
        		Write-Host "               - v$($_.Name -replace $chocoNupkgFileExpr, '$2')"
            }
    	}
    } else {
        Write-Message "Search root `chocoPkgsDir='$($searchRootDir)'` does not exist."
    }
}

task Choco:BuildPackages {
    if (-not($chocoSource)) {
        throw "Define property ```$chocoSource`` in order to deploy packages."
    }

    if ($chocoSource -match "^\\\\.+" -or $chocoSource -match "^[A-Z]:\\") {
        # Use a UNC path verbatim
        $chocoPullSource = $chocoSource
        $chocoPushSource = $chocoSource
    } else {
        if (-not($chocoApiKey)) {
            throw "Define property ```$chocoApiKey`` in order to deploy packages."
        }

        if ($chocoSource -eq "chocolatey.org") {
            $chocoPullSource = "https://chocolatey.org/api/v2/"
            $chocoPushSource = "https://push.chocolatey.org/"
        } elseif ($chocoSourceHost -eq 'myget') {
            $chocoPullSource = "https://www.myget.org/F/$chocoSource/auth/$chocoApiKey"
            $chocoPushSource = "https://www.myget.org/F/$chocoSource/api/v2/"
        } else {
            throw "Unknown chocolatey source '$($chocoSource)'."
        }
    }

    if ($chocoPkgsDir) {
        $searchRootDir = $chocoPkgsDir
    } else {
        $searchRootDir = Join-Path (Split-Path (Split-Path $psakeChocoRoot)) 'Chocolatey'
    }

    if (Test-Path $searchRootDir) {
        Write-Message "Building choco packages in '$($searchRootDir)'..."
        Get-ChildItem $searchRootDir -Filter *.nuspec -Recurse | where {
            if ((Test-Path "$($_.FullName).ignore") -or ($chocoIgnoreNuspecs -and $chocoIgnoreNuspecs -contains ([System.IO.Path]::GetFileNameWithoutExtension($_.Name)))) {
                Write-Warning "Ignoring package '$($_.Name)'."
            } else {
                return $true
            }
        } | ForEach-Object {
            Write-Message "Found '$($_.FullName)'..."
            $pkgFolder = Split-Path $_.FullName -Parent
            $pkgId = [System.IO.Path]::GetFileNameWithoutExtension((Split-Path $_.FullName -Leaf))
            $pkgXml = [xml](Get-Content $_.FullName)
            if ($pkgXml.package.metadata.version -eq '$version$') {
                $versionSearchStep = 0
                while (-not($pkgLocalVersionText) -and $versionSearchStep -ge 0) {
                    $versionSearchStep += 1

                    if ($versionSearchStep -eq 1) {
                        Write-Verbose "Looking for '$($pkgId).version' file..."
                        if (Test-Path (Join-Path $pkgFolder "$($pkgId).version")) {
                            $pkgLocalVersionText = (Get-Content (Join-Path $pkgFolder "$($pkgId).version")).Trim()
                        }
                    } elseif ($versionSearchStep -eq 2) {
                        if ($root -and $root -ne $pkgFolder) {
                            Write-Verbose "Looking for '$($pkgId).version' file in '$($root)'..."
                            if ($root -and $root -ne $pkgFolder -and (Test-Path (Join-Path $root "$($pkgId).version"))) {
                                $pkgLocalVersionText = (Get-Content (Join-Path $root "$($pkgId).version")).Trim()
                            }
                        }
                    } elseif ($versionSearchStep -eq 3) {
                        Write-Verbose "Looking for '$($pkgFolder)\**\$($pkgId).psd1'..."
                        if (Get-ChildItem $pkgFolder -Recurse -Include "$($pkgId).psd1" -EA 0) {
                            $pkgModuleManifest = Import-PSData (Get-ChildItem $pkgFolder -Recurse -Include "$($pkgId).psd1" -EA 0).FullName
                            $pkgLocalVersionText = $pkgModuleManifest.ModuleVersion
                        }
                    } elseif ($versionSearchStep -eq 4) {
                        if ($root -and $root -ne $pkgFolder) {
                            Write-Verbose "Looking for '$($root)\**\$($pkgId).psd1'..."
                            if (Get-ChildItem $root -Recurse "$($pkgId).psd1" -EA 0) {
                                $pkgModuleManifest = Import-PSData (Get-ChildItem $root -Recurse "$($pkgId).psd1" -EA 0).FullName
                                $pkgLocalVersionText = $pkgModuleManifest.ModuleVersion
                            }
                        }
                    } elseif ($versionSearchStep -eq 5) {
                        if ($pkgId.EndsWith('.Extension', 'CurrentCultureIgnoreCase')) {
                            Write-Verbose "Looking for '$($pkgFolder)\**\$($pkgId.Substring(0, $pkgId.Length - 10)).psd1'..."
                            if (Get-ChildItem $pkgFolder -Recurse -Include "$($pkgId.Substring(0, $pkgId.Length - 10)).psd1" -EA 0) {
                                $pkgModuleManifest = Import-PSData (Get-ChildItem $pkgFolder -Recurse -Include "$($pkgId.Substring(0, $pkgId.Length - 10)).psd1" -EA 0).FullName
                                $pkgLocalVersionText = $pkgModuleManifest.ModuleVersion
                            }
                        }
                    } elseif ($versionSearchStep -eq 6) {
                        if ($root -and $root -ne $pkgFolder -and $pkgId.EndsWith('.Extension', 'CurrentCultureIgnoreCase')) {
                            Write-Verbose "Looking for '$($root)\**\$($pkgId.Substring(0, $pkgId.Length - 10)).psd1'..."
                            if (Get-ChildItem $root -Recurse -Include "$($pkgId.Substring(0, $pkgId.Length - 10)).psd1" -EA 0) {
                                $pkgModuleManifest = Import-PSData (Get-ChildItem $root -Recurse -Include "$($pkgId.Substring(0, $pkgId.Length - 10)).psd1" -EA 0).FullName
                                $pkgLocalVersionText = $pkgModuleManifest.ModuleVersion
                            }
                        }
                    } else {
                        $versionSearchStep = -1
                    }
                }

                if (-not($pkgLocalVersionText)) {
                    Write-Error "Cannot determine local version of package '$($pkgId)'."
                    return
                }

                $pkgLocalVersion = [Version]::Parse($pkgLocalVersionText)
            } else {
                    $pkgLocalVersionText = $pkgXml.package.metadata.version
            }

            try {
                if ($pkgLocalVersionText -match '-') {
                    $pkgLocalVersion = ConvertTo-Version ($pkgLocalVersionText.Substring(0, $pkgLocalVersionText.IndexOf('-')))
                } else {
                    $pkgLocalVersion = ConvertTo-Version $pkgLocalVersionText
                }
            } catch {
                Write-Error "Unable to parse version text '$($pkgXml.package.metadata.version)'."
                return
            }

            Write-Message "Local version of '$($pkgId)' is v$($pkgLocalVersion)."
            Write-Message "Attempting to find latest version of '$($pkgId)'..."
            $pkgLatestVersionText = Get-ChocoLatestVersion -PackageId $pkgId -Source $chocoPullSource -ErrorAction SilentlyContinue
            if ($pkgLatestVersionText) {
                if ($pkgLatestVersionText -match '-') {
                    $pkgLatestVersion = ConvertTo-Version ($pkgLatestVersionText.Substring(0, $pkgLatestVersionText.IndexOf('-')))
                } else {
                    $pkgLatestVersion = ConvertTo-Version $pkgLatestVersionText
                }
            } else {
                $pkgLatestVersion = $null
            }
            if ($pkgLatestVersionText) {
                Write-Message "Latest version of '$($pkgId)' is v$($pkgLatestVersionText)."
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
                $pkgFile = New-ChocoPackage -NuspecFile $_.FullName -Version $pkgLocalVersionText -Force
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

task Choco:DeployPackages {
    if (-not($chocoSource)) {
        throw "Define property ```$chocoSource`` in order to deploy packages."
    }

    if ($chocoSource -match "^\\\\.+" -or $chocoSource -match "^[A-Z]:\\") {
        # Use a UNC path verbatim
        $chocoPullSource = $chocoSource
        $chocoPushSource = $chocoSource
    } else {
        if (-not($chocoApiKey)) {
            throw "Define property ```$chocoApiKey`` in order to deploy packages."
        }

        if ($chocoSource -eq "chocolatey.org") {
            $chocoPullSource = "https://chocolatey.org/api/v2/"
            $chocoPushSource = "https://push.chocolatey.org/"
        } elseif ($chocoSourceHost -eq 'myget') {
            $chocoPullSource = "https://www.myget.org/F/$chocoSource/auth/$chocoApiKey"
            $chocoPushSource = "https://www.myget.org/F/$chocoSource/api/v2/"
        } else {
            throw "Unknown chocolatey source '$($chocoSource)'."
        }
    }

    if ($chocoPkgsDir) {
        $searchRootDir = $chocoPkgsDir
    } else {
        $searchRootDir = Join-Path (Split-Path (Split-Path $psakeChocoRoot)) 'Chocolatey'
    }

    $packageMetadata = @{}

    if (Test-Path $searchRootDir) {
        Write-Message "Searching for nuspecs in '$($searchRootDir)'..."
        Get-ChildItem $searchRootDir -Filter *.nuspec -Recurse | where {
            if ((Test-Path "$($_.FullName).ignore") -or ($chocoIgnoreNuspecs -and $chocoIgnoreNuspecs -contains ([System.IO.Path]::GetFileNameWithoutExtension($_.Name)))) {
                Write-Warning "Ignoring package '$($_.Name)'."
            } else {
                return $true
            }
        } | ForEach-Object {
            Write-Verbose "Found '$($_.FullName)'..."
    		#Write-Host "             .\$($_.FullName.Substring($root.Length + 1))"
            $pkgFolder = Split-Path $_.FullName -Parent
            $pkgSpec = [xml](Get-Content $_.FullName)
            $pkgId = [System.IO.Path]::GetFileNameWithoutExtension((Split-Path $_.FullName -Leaf)).ToLower()
            $packageMetadata[$pkgId] = $pkgSpec.package.metadata
        }

        if ($chocoOutDir) {
            $searchRootDir = $chocoOutDir
        } else {
            $searchRootDir = Join-Path (Split-Path (Split-Path $psakeChocoRoot)) 'Chocolatey'
        }

        $packagesToPush = @()

    	Write-Message "Searching for packages in '$($searchRootDir)'..."
    	Get-ChildItem $searchRootDir -Filter *.nupkg | where {
            $pkgId = $_.Name -replace $chocoNupkgFileExpr, '$1'
            return $packageMetadata.Keys -contains $pkgId
        } | Group-Object {
            $_.Name -replace $chocoNupkgFileExpr, '$1'
        } | ForEach-Object {
    		Write-Verbose "Found package '$($_.Name)':"
            Write-Verbose "Attempting to find latest version of '$($_.Name)'..."
            $pkgLatestVersion = Get-ChocoLatestVersion -PackageId $_.Name -Pre -Source $chocoPullSource -ErrorAction SilentlyContinue
            $pkgVersions = Get-ChocoAllVersions -PackageId $_.Name -Pre -Source $chocoPullSource -ErrorAction SilentlyContinue
            if ($pkgVersions) {
                Write-Verbose "All versions of '$($_.Name)': $($pkgVersions -join ', ')."
            } else {
                Write-Verbose "Package '$($_.Name)' was not found."
            }
            Write-Host "             Found '$($_.Name)' (nuspec=$($packageMetadata[$_.Name].version);deployed=$($pkgLatestVersion)):"
            $_.Group | ForEach-Object {
                $pkgVersion = $_.Name -replace $chocoNupkgFileExpr, '$2'
                if ($pkgVersions -contains $pkgVersion) {
                    Write-Host "               - v$($_.Name -replace $chocoNupkgFileExpr, '$2')" -ForegroundColor DarkGray
                } else {
                    Write-Host "               - v$($_.Name -replace $chocoNupkgFileExpr, '$2')" -ForegroundColor Green
                    $packagesToPush += $_
                }
            }
    	}

        Write-Message "Pushing packages to $($chocoPushSource)..."
        $packagesToPush | foreach {
            Write-Host "             Pushing '$($_.Name)'..."
            Push-ChocoPackage -PackageFile $_.FullName -Source $chocoPushSource -ApiKey $chocoApiKey
        }
    } else {
        Write-Message "Search root `chocoPkgsDir='$($searchRootDir)'` does not exist."
    }
}
