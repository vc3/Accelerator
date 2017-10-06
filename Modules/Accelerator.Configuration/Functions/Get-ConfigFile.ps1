function Get-ConfigFile {
    [CmdletBinding()]
    param(
        [ValidateSet('CurrentCommandRoot', 'CurrentUser', 'LocalMachine', 'Legacy')]
        [string[]]$Scope = @('CurrentCommandRoot', 'CurrentUser', 'LocalMachine', 'Legacy'),

        [switch]$Force
    )

    $filesToCheck = @()

    $Scope | ForEach-Object {
        if ($_ -eq 'CurrentCommandRoot') {
            if ($AcceleratorCommandFileName) {
                Write-Verbose "Searching for command root from script '$($AcceleratorCommandFileName)'."
                $scriptDir = Split-Path $AcceleratorCommandFileName -Parent
            } else {
                Write-Warning "Can't get current command root without variable 'AcceleratorCommandFileName'."
                $scriptDir = $null
            }

            if ($scriptDir) {
                if ((Split-Path $scriptDir -Leaf) -eq 'Commands') {
                    Write-Verbose "Including parent of the 'Commands' directory from script location '$($scriptDir)'."
                    $fileName = "$(Split-Path $scriptDir -Parent)\Accelerator.cfg"
                    $cf = New-Object 'PSObject'
                    $cf | Add-Member -Type 'NoteProperty' -Name 'Scope' -Value $_
                    $cf | Add-Member -Type 'NoteProperty' -Name 'Path' -Value $fileName
                    $filesToCheck += $cf
                } else {
                    $nestedDir = Split-Path $scriptDir -Parent
                    if ((Split-Path $nestedDir -Leaf) -eq 'Commands') {
                        Write-Verbose "Including parent of the 'Commands' directory from script location '$($scriptDir)'."
                        $fileName = "$(Split-Path $nestedDir -Parent)\Accelerator.cfg"
                        $cf = New-Object 'PSObject'
                        $cf | Add-Member -Type 'NoteProperty' -Name 'Scope' -Value $_
                        $cf | Add-Member -Type 'NoteProperty' -Name 'Path' -Value $fileName
                        $filesToCheck += $cf
                    } else {
                        Write-Warning "Unable to find the 'Commands' directory from script location '$($scriptDir)'."
                    }
                }
            }
        } elseif ($_ -eq 'CurrentUser') {
            Write-Verbose "Including legacy config location '%APPDATA%\Accelerator\Accelerator.cfg'."
            $fileName = "$($env:APPDATA)\Accelerator\Accelerator.cfg"
            $cf = New-Object 'PSObject'
            $cf | Add-Member -Type 'NoteProperty' -Name 'Scope' -Value $_
            $cf | Add-Member -Type 'NoteProperty' -Name 'Path' -Value $fileName
            $filesToCheck += $cf
        } elseif ($_ -eq 'LocalMachine') {
            Write-Verbose "Including legacy config location '%ALLUSERSPROFILE%\Accelerator\Accelerator.cfg'."
            $fileName = "$($env:ALLUSERSPROFILE)\Accelerator\Accelerator.cfg"
            $cf = New-Object 'PSObject'
            $cf | Add-Member -Type 'NoteProperty' -Name 'Scope' -Value $_
            $cf | Add-Member -Type 'NoteProperty' -Name 'Path' -Value $fileName
            $filesToCheck += $cf
        } elseif ($_ -eq 'Legacy') {
            if ($AcceleratorRoot) {
                Write-Verbose "Including legacy config location '`$AcceleratorRoot\Accelerator.cfg'."
                $fileName = "$($AcceleratorRoot)\Accelerator.cfg"
                $cf = New-Object 'PSObject'
                $cf | Add-Member -Type 'NoteProperty' -Name 'Scope' -Value $_
                $cf | Add-Member -Type 'NoteProperty' -Name 'Path' -Value $fileName
                $filesToCheck += $cf
            } else {
                Write-Warning "Variable 'AcceleratorRoot' is not defined."
            }
        }
    }

    if ($filesToCheck.Count -eq 0) {
        Write-Error "Unable to find config files for scopes $($Scope -join ',')."
        return
    }

    $files = @()

    $filesToCheck | ForEach-Object {
        if (Test-Path $_.Path) {
            Write-Verbose "Found config file '$($_.Path)'."
            $files += $_
        } elseif ($Force.IsPresent) {
            Write-Verbose "Forcing non-existant file '$($_.Path)'."
            $files += $_
        } else {
            Write-Verbose "File '$($_.Path)' doesn't exist."
        }
    }

    if ($files -eq 0) {
        Write-Error "Unable to find any of the following config files:`r`n$(($filesToCheck | Select-Object -ExpandProperty 'Path') -join "`r`n")" -Category 'ResourceUnavailable' -ErrorId 42286
        return
    }

    return $files
}
