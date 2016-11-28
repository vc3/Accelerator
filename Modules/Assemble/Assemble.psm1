function GetTempDirectory {
    $tempDir = [system.io.path]::GetTempPath()
    $rndName = [system.io.path]::GetRandomFileName()
    $path = Join-Path $tempDir $rndName
    New-Item $path -Type Directory | Out-Null
    foreach ($a in $args) {
        New-Item $path\$a -Type Directory | Out-Null
    }
    return $path
}

function EnsureDirectory ([string]$path, [boolean]$defaultToCurrentLocation) {
    if ($path) {
        $path = $path.Trim()
    }

    if (!$path -and $defaultToCurrentLocation) {
        $path = Get-Location
    }
    elseif (!(Test-Path $path)) {
        Write-Error "Path '$($path)' does not exist."
        exit 1
    }
    else {
        $path = (Resolve-Path $path).Path
        if (!(Get-Item $path).PSIsContainer) {
            Write-Error "Path '$($path)' must be a directory."
            exit 1
        }
    }

    return $path
}


function Invoke-ScriptBuild {
	[CmdletBinding()]
	param(
	    [Parameter(Mandatory=$true, HelpMessage="Name of the module or script to build")]
	    [string]$Name,
	
	    [Parameter(Mandatory=$false, HelpMessage="Path to the directory that contains the source files to include")]
	    [string[]]$SourcePath,
	
	    [Parameter(Mandatory=$false, HelpMessage="Path to the directory or file where the output will be copied")]
	    [string]$TargetPath,
	
	    [Alias('Type')]
	    [ValidateSet('Auto', 'Module', 'Script')]
	    [Parameter(Mandatory=$false, HelpMessage="The type of output file to produce")]
	    [string]$OutputType,
	
	    [Alias('DependenciesToValidate')]
	    [Parameter(Mandatory=$false, HelpMessage="The names of dependent modules to validate")]
	    [array]$RequiredModules=@(),
	
	    [Parameter(Mandatory=$false, HelpMessage="Forcibly copy over the module or script file if it already exists")]
	    [switch]$Force,
	
	    [Parameter(Mandatory=$false, HelpMessage="PowerShell scripts (.ps1) to exclude from source files")]
	    [string[]]$Exclude,
	
	    [Alias('Export')]
	    [Parameter(Mandatory=$false, HelpMessage="Symbols to export when compiling a module.")]
	    [string[]]$SymbolsToExport,
	
	    [Parameter(Mandatory=$false, HelpMessage="Flags used by preprocessor.")]
	    [string[]]$Flags,
	
		[Parameter(Mandatory=$false, HelpMessage="Don't write status messages.")]
		[switch]$Silent
	)
	
	
	# Ensure that the source and target paths valid directories if specified
	if ($SourcePath -and $SourcePath.Count -gt 0) {
	    $SourcePath | foreach {
	        if (-not(Test-Path $_)) {
	            Write-Error "Path '$($_)' does not exist."
	            exit 1
	        } elseif (!(Get-Item $_).PSIsContainer -and [System.IO.Path]::GetExtension($_) -ne '.ps1') {
	            Write-Error "Path '$($_)' must be a directory or '.ps1' file."
	            exit 1
	        }
	    }
	} else {
	    $path = $SourcePath = [array](@((Get-Location).Path))
	}
	
	if (-not($OutputType)) {
	    if ($TargetPath) {
	        if (((Test-Path $TargetPath) -and (Get-Item $TargetPath) -is [System.IO.FileInfo]) -or (-not(Test-Path $TargetPath) -and [System.IO.Path]::GetExtension($TargetPath))) {
	            # Deafult to 'Auto' for specific file path output
	            $OutputType = 'Auto'
	        } else {
	            # Assume output to directory, and default to 'Module'...
	            $OutputType = 'Module'
	        }
	    } else {
	        $OutputType = 'Module'
	    }
	}
	
	if ($OutputType -eq 'Auto') {
	    if ($TargetPath) {
	        # Infer output type from file extension
	        $targetPathExt = [System.IO.Path]::GetExtension($TargetPath)
	        if ($targetPathExt -eq '.psm1') {
	            $OutputType = 'Module'
	        } elseif ($targetPathExt -eq '.ps1') {
	            $OutputType = 'Script'
	        } else {
	            Write-Error "Unsupported file extension '$($targetPathExt)'."
	            return
	        }
	    } else {
	        Write-Error "Target path must be a file in order to use -OutputType 'Auto'."
	        return
	    }
	}
	
	if ($OutputType -eq 'Module') {
	    $tempFileName = "$($Name).psm1"
	    if ($TargetPath -and (((Test-Path $TargetPath) -and (Get-Item $TargetPath) -is [System.IO.FileInfo]) -or (-not(Test-Path $TargetPath) -and [System.IO.Path]::GetExtension($TargetPath)))) {
	        # Use provided module path
	        $OutputPath = $TargetPath
	    } else {
	        $TargetPath = EnsureDirectory $TargetPath $true
	        $OutputPath = Join-Path $TargetPath "$($Name).psm1"
	    }
	} elseif ($OutputType -eq 'Script') {
	    if ($SymbolsToExport) {
	        Write-Error "Symbols to export is not valid for script output."
	        return
	    }
	    $tempFileName = "$($Name).ps1"
	    if ($TargetPath -and (((Test-Path $TargetPath) -and (Get-Item $TargetPath) -is [System.IO.FileInfo]) -or (-not(Test-Path $TargetPath) -and [System.IO.Path]::GetExtension($TargetPath)))) {
	        # Use provided script path
	        $OutputPath = $TargetPath
	    } else {
	        $TargetPath = EnsureDirectory $TargetPath $true
	        $OutputPath = Join-Path $TargetPath "$($Name).ps1"
	    }
	} else {
	    Write-Error "Unexpected -OutputType '$($OutputType)'."
	    return
	}
	
	# Create a temporary directory to build in
	$buildDir = GetTempDirectory
	
	if ($Silent.IsPresent) {
		Write-Verbose "Starting script build for $($OutputType.ToLower()) '$($Name)'."
	} else {
		Write-Host "Starting script build for $($OutputType.ToLower()) '$($Name)'."
	}
	
	Write-Verbose "NOTE: Building in temporary directory '$($buildDir)'..."
	
	$tempPath = "$buildDir\$($tempFileName)"
	
	if ($Silent.IsPresent) {
		Write-Verbose "Creating empty $($OutputType.ToLower()) file..."
	} else {
		Write-Host "Creating empty $($OutputType.ToLower()) file..."
	}
	
	New-Item $tempPath -Type File | Out-Null
	
	# Ensure that required modules are available and loaded
	$RequiredModules | foreach {
	    Write-Verbose "Adding dependency to" + $_
	    Add-Content -Path $tempPath -Value ("if (!(Get-Module " + $_ + ")) {")
	    Add-Content -Path $tempPath -Value ("`tImport-Module " + $_ + " -ErrorAction Stop")
	    Add-Content -Path $tempPath -Value "}"
	    Add-Content -Path $tempPath -Value ""
	}
	
	$symbols = @()
	$sources = @()
	
	if ($Silent.IsPresent) {
		Write-Verbose "Searching for source files to include..."
	} else {
		Write-Host "Searching for source files to include..."
	}
	
	$mainFile = $null
	$initFile = $null
	$finalFile = $null
	
	Get-ChildItem -Path $SourcePath -Exclude $Exclude -Filter "*.ps1" -Recurse | %{
	    if ($_.Name -eq "__main__.ps1") {
	        if ($OutputType -eq 'Script') {
	            Write-Verbose "Found __main__ (entry) file."
	            $sources += $_.FullName
	            if ($mainFile) {
	                Write-Error "Found multiple '__main__.ps1' files."
	                return
	            } elseif ($finalFile) {
	                if ($Silent.IsPresent) {
	                    Write-Verbose "HINT: You may be able to consolidate entry (__main__.ps1) and final (__final__.ps1) files."
	                } else {
	                    Write-Warning "HINT: You may be able to consolidate entry (__main__.ps1) and final (__final__.ps1) files."
	                }
	            }
	            $mainFile = $_.FullName
	        } else {
	            Write-Error "Entry file '__main__.ps1' is only valid for script file output."
	        }
	    } elseif ($_.Name -eq "__init__.ps1") {
	        Write-Verbose "Found __init__ (initialize) file."
	        $sources += $_.FullName
	        if ($initFile) {
	            Write-Error "Found multiple '__init__.ps1' files."
	            return
	        }
	        $initFile = $_.FullName
	    }
	    elseif ($_.Name -eq "__final__.ps1") {
	        Write-Verbose "Found __final__ (finalize) file."
	        $sources += $_.FullName
	        if ($finalFile) {
	            Write-Error "Found multiple '__final__.ps1' files."
	            return
	        } elseif ($mainFile) {
	            if ($Silent.IsPresent) {
	                Write-Verbose "HINT: You may be able to consolidate entry (__main__.ps1) and final (__final__.ps1) files."
	            } else {
	                Write-Warning "HINT: You may be able to consolidate entry (__main__.ps1) and final (__final__.ps1) files."
	            }
	        }
	        $finalFile = $_.FullName
	    }
	    elseif ($_.Name -match "([A-Z][a-z]+`-[A-Z][A-Za-z]+)`.ps1") {
	        Write-Verbose "Found source file $($_)."
	        $symbols += $_.Name -replace ".ps1", ""
	        $sources += $_.FullName
	    }
	    else {
	        throw "Invalid file name '$($_.Name)'."
	    }
	}
	
	Write-Verbose "Symbols: $symbols"
	
	$initFileExpr = "^\s*\. \.\\__init__\.ps1$"
	
	$ifExpr = "^\s*#if"
	$ifDefExpr = "^\s*#ifdef\s+(.+)\s*$"
	
	if ($Silent.IsPresent) {
		Write-Verbose "Including source files..."
	} else {
		Write-Host "Including source files..."
	}
	
	if ($initFile) {
	    Write-Verbose "Including file __init__.ps1"
	    $ignore = $false
	    (Get-Content $initFile | % {
	        if ($_ -match $ifExpr) {
	            if ($_ -match $ifdefExpr) {
	                $flag = $_ -replace $ifdefExpr, '$1'
	                Write-Verbose "Checking for flag $($flag)..."
	                if ($Flags -contains $flag) {
	                    Write-Verbose "Found flag $flag."
	                }
	                else {
	                    Write-Verbose "Did not find flag $flag. Ignoring content..."
	                    $ignore = $true
	                }
	            }
	            else {
	                throw "Invalid #if block: $_"
	            }
	        }
	        elseif ($_ -match "^\s*#endif\s*$") {
	            $ignore = $false
	        }
	        elseif ($ignore) {
	            Write-Verbose "Ignored: $_"
	        }
	        else {
	            Write-Output $_
	        }
	    }) | Add-Content -Path $tempPath
	    Add-Content -Path $tempPath -Value "`r`n"
	}
	
	$sources | sort Name | foreach {
	    if ($_ -ne $initFile -and $_ -ne $finalFile -and $_ -ne $mainFile) {
	        $n = ((Split-Path -Path $_ -Leaf) -replace ".ps1", "")
	        Write-Verbose "Including file $($n).ps1"
	        if ($n -ne "__init__") {
	            Add-Content -Path $tempPath -Value ("function " + $n + " {")
	        }
	        $ignore = $false
	        ((Get-Content $_) | % {
	            if ($_ -match $ifExpr) {
	                if ($_ -match $ifdefExpr) {
	                    $flag = $_ -replace $ifdefExpr, '$1'
	                    Write-Verbose "Checking for flag $($flag)..."
	                    if ($Flags -contains $flag) {
	                        Write-Verbose "Found flag $flag."
	                    }
	                    else {
	                        Write-Verbose "Did not find flag $flag. Ignoring content..."
	                        $ignore = $true
	                    }
	                }
	                else {
	                    throw "Invalid #if block: $_"
	                }
	            }
	            elseif ($_ -match "^\s*#endif\s*$") {
	                $ignore = $false
	            }
	            elseif ($ignore) {
	                Write-Verbose "Ignored: $_"
	            }
	            else {
	                $newLine = "`t" + $_
	                $foundFileRefs = $false
	                if ($newLine -match $initFileExpr) {
	                    $newLine = ""
	                    $foundFileRefs = $true
	                    Write-Verbose "Removed dot-source of '__init__.ps1'."
	                }
	                else {
	                    $symbols | foreach {
	                        $symbolExpr = "\.\\$([Regex]::Escape($_))\.ps1"
	                        if ($newLine -match $symbolExpr) {
	                            $foundFileRefs = $true
	                            $newLine = $newLine -replace $symbolExpr, $_
	                            Write-Verbose "Found file reference to symbol '$($_)'."
	                        } else {
	                            $symbolExpr2 = "& `"\`$\(\`$PSScriptRoot\)\\$([Regex]::Escape($_))\.ps1`""
	                            if ($newLine -match $symbolExpr2) {
	                                $foundFileRefs = $true
	                                $newLine = $newLine -replace $symbolExpr2, $_
	                                Write-Verbose "Found file reference to symbol '$($_)'."
	                            }
	                        }
	                    }
	                    if ($foundFileRefs -eq $true) {
	                        Write-Verbose "Result: $newLine"
	                    }
	                }
	                if ($newLine) {
	                    Write-Output $newLine
	                }
	            }
	        }) | Add-Content -Path $tempPath
	        if ($n -ne "__init__") {
	            Add-Content -Path $tempPath -Value "}`r`n"
	        }
	    }
	}
	
	if ($OutputType -eq 'Module') {
	    if ($Silent.IsPresent) {
	    	Write-Verbose "Registering export for symbols..."
	    } else {
	    	Write-Host "Registering export for symbols..."
	    }
	
	    $symbols | foreach {
	        if (-not($SymbolsToExport) -or ($SymbolsToExport -contains $_)) {
	            Add-Content -Path $tempPath -Value "Export-ModuleMember -Function '$($_)'"
	        }
	    }
	}
	
	if ($mainFile) {
	    Write-Verbose "Including file __main__.ps1"
	    $ignore = $false
	    (Get-Content $mainFile | % {
	        if ($_ -match $ifExpr) {
	            if ($_ -match $ifdefExpr) {
	                $flag = $_ -replace $ifdefExpr, '$1'
	                Write-Verbose "Checking for flag $($flag)..."
	                if ($Flags -contains $flag) {
	                    Write-Verbose "Found flag $flag."
	                }
	                else {
	                    Write-Verbose "Did not find flag $flag. Ignoring content..."
	                    $ignore = $true
	                }
	            }
	            else {
	                throw "Invalid #if block: $_"
	            }
	        }
	        elseif ($_ -match "^\s*#endif\s*$") {
	            $ignore = $false
	        }
	        elseif ($ignore) {
	            Write-Verbose "Ignored: $_"
	        }
	        else {
	            Write-Output $_
	        }
	    }) | Add-Content -Path $tempPath
	    Add-Content -Path $tempPath -Value "`r`n"
	}
	
	if ($finalFile) {
	    Write-Verbose "Including file __final__.ps1"
	    $ignore = $false
	    (Get-Content $finalFile | % {
	        if ($_ -match $ifExpr) {
	            if ($_ -match $ifdefExpr) {
	                $flag = $_ -replace $ifdefExpr, '$1'
	                Write-Verbose "Checking for flag $($flag)..."
	                if ($Flags -contains $flag) {
	                    Write-Verbose "Found flag $flag."
	                }
	                else {
	                    Write-Verbose "Did not find flag $flag. Ignoring content..."
	                    $ignore = $true
	                }
	            }
	            else {
	                throw "Invalid #if block: $_"
	            }
	        }
	        elseif ($_ -match "^\s*#endif\s*$") {
	            $ignore = $false
	        }
	        elseif ($ignore) {
	            Write-Verbose "Ignored: $_"
	        }
	        else {
	            Write-Output $_
	        }
	    }) | Add-Content -Path $tempPath
	    Add-Content -Path $tempPath -Value "`r`n"
	}
	
	# Copy completed file to the target path
	
	if ((Test-Path -Path $OutputPath) -and !$Force.IsPresent) {
	    throw "File '$($OutputPath)' already exists!"
	}
	
	if ($Silent.IsPresent) {
		Write-Verbose "Moving completed $($OutputType.ToLower()) to '$($TargetPath)'..."
	} else {
		Write-Host "Moving completed $($OutputType.ToLower()) to '$($TargetPath)'..."
	}
	
	Copy-Item $tempPath $OutputPath -Force | Out-Null
}

Export-ModuleMember -Function Invoke-ScriptBuild
