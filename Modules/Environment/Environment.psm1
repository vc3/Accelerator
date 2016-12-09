function Optimize-EnvironmentPath {
	Param (
		[ValidateSet("Process", "User", "Machine")]
		[Parameter(Position=0,Mandatory=1)]
		[string]$Target,
		[Parameter(Position=1,Mandatory=0)]
		[string]$Name="Path"
	)

	$path = [Environment]::GetEnvironmentVariable($Name, $Target)

	if ($path) {
		$pathItems = New-Object System.Collections.ArrayList(,$path.Split(";"))

		$removedItems = @()
		$condensedItems = @()

		$pfx86 = ${env:ProgramFiles(x86)}
		$pfx86SN = Get-Item $pfx86 | Get-ItemShortName

		if ($pfx86 -ne $env:ProgramFiles) {
			$pf = $env:ProgramFiles
			$pfSN = Get-Item $pf | Get-ItemShortName
		}

		for ($i = 0; $i -lt $pathItems.Count; $i++) {
			$item = $pathItems[$i]
			if (!(Test-Path $item)) {
				Write-Host "Path '$($item)' does not exist."
				$choices = New-Object System.Collections.ObjectModel.Collection[System.Management.Automation.Host.ChoiceDescription]
				$choices.Add((New-Object "System.Management.Automation.Host.ChoiceDescription" -ArgumentList @("&Yes", "Confirms that the proposed action will be taken.")))
				$choices.Add((New-Object "System.Management.Automation.Host.ChoiceDescription" -ArgumentList @("&No", "The proposed action will not be taken.")))
				if ($host.ui.PromptForChoice("", "Would you like to remove this item from the $Target '$($Name)'?", $choices, 1) -eq 0) {
					$removedItems += $item
					$pathItems.RemoveAt($i)
					Write-Host "Removing value '$item' from the path registry setting..."
					$i--
				}
			}
			else {
				if ($item -match [regex]::Escape($pfx86) -and ($item.Split("\") -contains $pfx86)) {
					$condensedItem = $item.Replace($pfx86, $pfx86SN)
				}
				elseif ($pf -and $item -match [regex]::Escape($pf) -and ($item.Split("\") -contains $pf)) {
					$condensedItem = $item.Replace($pf, $pfSN)
				}
				if ($condensedItem -and $condensedItem.Length -lt $item.Length) {
					Write-Host "Path '$($item)' can be condensed to '$($condensedItem)'."
					$choices = New-Object System.Collections.ObjectModel.Collection[System.Management.Automation.Host.ChoiceDescription]
					$choices.Add((New-Object "System.Management.Automation.Host.ChoiceDescription" -ArgumentList @("&Yes", "Confirms that the proposed action will be taken.")))
					$choices.Add((New-Object "System.Management.Automation.Host.ChoiceDescription" -ArgumentList @("&No", "The proposed action will not be taken.")))
					if ($host.ui.PromptForChoice("", "Would you like to condense the path item?", $choices, 1) -eq 0) {
						$condensedItems += $item
						$pathItems[$i] = $condensedItem
						Write-Host "Condensing item '$(item)'..."
					}
				}
				$condensedItem = $null
			}
		}

		if ($removedItems.Count -gt 0) {
			$newPath = [string]::join(";", $pathItems.ToArray()).Trim(";")
			[Environment]::SetEnvironmentVariable($Name, $newPath, $Target)
			Write-Host "New $Target '$Name': $newPath"
		}
		else {
			Write-Host "No items were removed."
		}
	}
	else {
		Write-Host "$Target '$Name' does not exist or is empty."
	}
}

function Remove-EnvironmentPath {
	Param (
		[ValidateSet("Process", "User", "Machine")]
		[Parameter(Position=0,Mandatory=1)]
		[string]$Target,

		[Parameter(Position=1,Mandatory=0)]
		[string]$Name="Path",

		[Parameter(Position=2,Mandatory=1,ValueFromPipeline=$true)]
		[string]$Value,

		[Parameter(Position=3,Mandatory=0)]
		[switch]$FailIfMissing
	)

	$Value = $Value.Trim(";")

	$path = [Environment]::GetEnvironmentVariable($Name, $Target)

	$pathItems = $path.Split(";")

	if ($pathItems -contains $Value) {
		$pathList = New-Object System.Collections.ArrayList
		$pathList.AddRange($pathItems)

		# Account for the possibility that the same path exists more than once
		do {
			$previousLen = $pathList.Count
			$pathList.Remove($Value)
		} while ($pathList.Count -lt $previousLen)

		$newPath = [string]::join(";", $pathList.ToArray()).Trim(";")

		# If the name is "PATH", then determine whether to remove from the current session path.
		if ($Name.ToLower() -eq "path") {
			Write-Verbose "Searching for $Value in the current session '$($Name)'..."

			# If value exists in current path value, then try to remove it
	        $sessionValue = Get-Item "env:$($Name)" -ErrorAction SilentlyContinue

	        if ($sessionValue -and $sessionValue.Value) {
	    		$sessionPathItems = $sessionValue.Value.Split(";")
	        } else {
	            $sessionPathItems = @()
	        }

			if ($sessionPathItems -contains $Value) {
				$removeFromSession = $true
				Write-Verbose "Found $Value in the current session path, determining whether to keep..."
				if ($Target -ne "Process") {
					$otherTarget = if ($Target -eq "User") { "Machine" } else { "User" }

					# If not, then don't remove it from the current path value if it is on the global path or occurs more than once in the current value
					$otherPath = [Environment]::GetEnvironmentVariable("PATH", $otherTarget)
					if ($otherPath -match ($Value.Replace("\", "\\") + "(;|$)")) {
						$removeFromSession = $false
						Write-Verbose "WARNING: Value '$Value' also exists on the $otherTarget path, so it was not removed from the current session."
					}
				}

				if ($removeFromSession) {
					$pathList = New-Object System.Collections.ArrayList
					$pathList.AddRange($sessionPathItems)

					# Account for the possibility that the same path exists more than once
					do {
						$previousLen = $pathList.Count
						$pathList.Remove($Value)
					} while ($pathList.Count -lt $previousLen)

	                Set-Item "env:$($Name)" ([string]::join(";", $pathList.ToArray()).Trim(";"))
				}
			}
			else {
				if ($FailIfMissing.IsPresent) {
					throw "Value '$Value' could not be found in the current environment variable value '$envPath'."
				}
				else {
					Write-Verbose "Value '$Value' could not be found in the current environment variable value '$envPath'."
					exit 0
				}
			}
		}

		[Environment]::SetEnvironmentVariable($Name, $newPath, $Target)
		Write-Verbose "Removed value '$Value' from the path registry setting."
		Write-Verbose "Note that it may still be on the path if it is present in the system path or if the path was modified in this session."

		Write-Verbose "New $Target '$Name': $newPath"
	}
	else {
		if ($FailIfMissing.IsPresent) {
			throw "$Target '$Name' does not contain '$Value'"
		}
		else {
			Write-Verbose "$Target '$Name' does not contain '$Value'."
		}
	}
}

function Get-ItemShortName {
	# http://blogs.technet.com/b/heyscriptingguy/archive/2013/08/01/use-powershell-to-display-short-file-and-folder-names.aspx
	function Get-ShortName {
		begin {
			$fso = New-Object -ComObject Scripting.FileSystemObject
		}
		process {
			if ($_.PSIsContainer) {
				$fso.GetFolder($_.FullName).ShortName
			}
			else {
				$fso.GetFile($_.FullName).ShortName
			}
		}
	}
}

function Add-EnvironmentPath {
	Param (
		[ValidateSet("Process", "User", "Machine")]
		[Parameter(Position=0,Mandatory=1)]
		[string]$Target,

		[Parameter(Position=1,Mandatory=0)]
		[string]$Name="Path",

		[Parameter(Position=2,Mandatory=1,ValueFromPipeline=$true)]
		[string]$Value
	)

	$Value = $Value.Trim(";")

	$path = [Environment]::GetEnvironmentVariable($Name, $Target)

	if (!$path) {
		$path = ""
	}

	if (!($path.Split(";") -contains $Value)) {
		# Value is not in the path

		# Verify that it is a valid
		if (!(Test-Path -path $Value)) {
			throw "Path '$Value' does not exist."
		}

		# Ensure that path would not be too long: http://support.microsoft.com/kb/906469
		$availableChars = 2048 - $path.Length - 1
		if ($Value.Length -gt $availableChars) {
	        if ($Interactive.IsPresent) {
	    		Write-Host "The maximum path length will be exceeded."
	    		$choices = New-Object System.Collections.ObjectModel.Collection[System.Management.Automation.Host.ChoiceDescription]
	    		$choices.Add((New-Object "System.Management.Automation.Host.ChoiceDescription" -ArgumentList @("&Yes", "Confirms that the proposed action will be taken.")))
	    		$choices.Add((New-Object "System.Management.Automation.Host.ChoiceDescription" -ArgumentList @("&No", "The proposed action will not be taken.")))
	    		if ($host.ui.PromptForChoice("", "Would you like to attempt to optimize the path?", $choices, 1) -eq 0) {
	    			Optimize-EnvironmentPath -Target $Target -Name $Name
	    			$path = [Environment]::GetEnvironmentVariable($Name, $Target)
	    			$availableChars = 2048 - $path.Length - 1
	    			if ($Value.Length -gt $availableChars) {
	    				Write-Host "Path is still too long."
	    				$choices = New-Object System.Collections.ObjectModel.Collection[System.Management.Automation.Host.ChoiceDescription]
	    				$choices.Add((New-Object "System.Management.Automation.Host.ChoiceDescription" -ArgumentList @("&Yes", "Confirms that the proposed action will be taken.")))
	    				$choices.Add((New-Object "System.Management.Automation.Host.ChoiceDescription" -ArgumentList @("&No", "The proposed action will not be taken.")))
	    				if ($host.ui.PromptForChoice("", "Would you still like to continue?", $choices, 1) -ne 0) {
	    					return
	    				}
	    			}
	    			else {
	    				Write-Host "The path was successfully optimized!"
	    			}
	    		}
	        } else {
	    		Write-Warning "The maximum path length will be exceeded."
	        }
		}

		if ($path.Length -gt 0) {
			# Add to existing path
			$newPath = $path + ";" + $Value
		}
		else {
			# No existing path, so just set to new path
			$newPath = $Value
		}

		[Environment]::SetEnvironmentVariable($Name, $newPath, $Target)
		Write-Verbose "Added value '$Value' to the $Target $Name variable."
	}
	else {
		Write-Verbose "Path already contains '$($Value)'."
	}

	$currentValue = Get-Item "env:$($Name)" -ErrorAction SilentlyContinue
	if ($currentValue) {
		if ($currentValue.Value -match ($Value.Replace("\", "\\") + "(;|$)")) {
			Write-Verbose "Value already existed on the path for the current session."
		}
		else {
	        Set-Item "env:$($Name)" ($currentValue.Value + ";" + $Value) | Out-Null
			Write-Verbose "Value also added for the current session."
		}
	} else {
	    Set-Item "env:$($Name)" $Value | Out-Null
		Write-Verbose "Value also added for the current session."
	}

	if ($newPath) {
		Write-Verbose "New $Target '$Name': $newPath"
	}
}

function Get-EnvironmentPath {
	Param (
	    # The name of the environment variable to return.
		[Parameter()]
		[string]$Name="Path",

	    # If specified, returns the value of the variable as a semicolon-delimited string.
	    [Parameter(Mandatory=$false)]
	    [switch]$AsString,

	    # If specified, returns the persisted value of path variable.
	    [Parameter(Mandatory=$false)]
	    [switch]$Persisted
	)

	$currentVar = Get-Item "env:$($Name)" -ErrorAction SilentlyContinue
	if ($currentVar) {
	    $currentValue = (Get-Item "env:$($Name)").Value.Split(@(';'), 'RemoveEmptyEntries') -join ';'
	} else {
	    $currentValue = ""
	}

	if ($Persisted.IsPresent) {
	    $pathItems = @()

	    if ($Name -eq 'PSModulePath') {
	        $userValue = [Environment]::GetEnvironmentVariable($Name, 'User')
	        if ($userValue) {
	            $pathItems += $userValue.Split(@(';'), 'RemoveEmptyEntries')
	        }

	        $pathItems += "$($env:ProgramFiles)\WindowsPowerShell\Modules"
	    }

	    $systemValue = [Environment]::GetEnvironmentVariable($Name, 'Machine')
	    if ($systemValue) {
	        $pathItems += $systemValue.Split(@(';'), 'RemoveEmptyEntries')
	    }

	    if ($Name -ne 'PSModulePath') {
	        $userValue = [Environment]::GetEnvironmentVariable($Name, 'User')
	        if ($userValue) {
	            $pathItems += $userValue.Split(@(';'), 'RemoveEmptyEntries')
	        }
	    }

	    $persistedValue = ($pathItems -join ';')

	    if ($currentValue -ne $persistedValue) {
	        <#
	        $currentPath = [System.IO.Path]::GetTempFileName()
	        $persistedPath = [System.IO.Path]::GetTempFileName()
	        Write-Verbose "Writing current to '$($currentPath)' and persisted to '$($persistedPath)'."
	        $currentValue | Out-File $currentPath -Encoding UTF8
	        $persistedValue | Out-File $persistedPath -Encoding UTF8
	        #>

	        Write-Verbose "Current and persisted value for environment variable '$($Name)' do not match."
	    }

	    if ($AsString.IsPresent) {
	        $returnValue = ($pathItems -join ';')
	    } else {
	        $returnItems = $pathItems
	    }
	} else {
	    if ($AsString.IsPresent) {
	        $returnValue = $currentValue
	    } else {
	        $returnItems = $currentValue.Split(@(';'), 'RemoveEmptyEntries')
	    }
	}

	if ($AsString.IsPresent) {
	    return $returnValue
	} else {
	    $returnItems | foreach {
			$item = New-Object 'PSObject'
			$item | Add-Member -Type NoteProperty -Name 'Path' -Value $_
			Write-Output $item
	    }
	}
}

Export-ModuleMember -Function 'Add-EnvironmentPath'
Export-ModuleMember -Function 'Get-EnvironmentPath'
Export-ModuleMember -Function 'Remove-EnvironmentPath'
