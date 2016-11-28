[CmdletBinding()]
param(
    [string]$AcceleratorPath
)

if (-not($PSScriptRoot)) {
    $PSScriptRoot = Split-Path $script:MyInvocation.MyCommand.Path
}

Import-Module "$($PSScriptRoot)\..\Accelerator.psd1"

if ($AcceleratorPath) {
    $pathRoots = [array]($AcceleratorPath -split ';')
} else {
    $pathRoots = & "$($PSScriptRoot)\Get-AcceleratorPath.ps1" -AsArray
}

foreach ($root in $pathRoots) {
    if (Test-Path "$($root)\Commands") {
        Write-Verbose "Scanning directory '$($root)\Commands'..."

        $children = [array](Get-ChildItem "$($root)\Commands")

        $hasFiles = $false
        $hasFolders = $false

        foreach ($c in $children) {
            Write-Verbose "Checking child item '$($c.Name)'..."
            if ($c -is [System.IO.DirectoryInfo]) {
                if (Get-ChildItem $c.FullName -Filter '*.ps1') {
                    Write-Verbose "Found command file(s) in folder '$($c.FullName)'."
                    $hasFolders = $true
                } else {
                    Write-Warning "Found empty folder '$($c.FullName)'."
                }
            } elseif ([IO.Path]::GetExtension($c.Name) -eq '.ps1') {
                Write-Verbose "Found command file(s) in folder '$($root)\Commands'."
                $hasFiles = $true
            }
        }

        if ($hasFiles) {
            if ($hasFolders) {
                Write-Warning "Found a mix of command files and folders in '$($root)\Commands'."
            }

            Write-Verbose "Importing command files in '$($root)\Commands'..."

            $module = "$(Split-Path $root -Leaf)" -replace '%20', ' '

            $children | where { -not($_ -is [System.IO.DirectoryInfo]) -and [IO.Path]::GetExtension($_.Name) -eq '.ps1' } | foreach {
                Write-Verbose "Found command file '$($_.Name)'."
                Write-Output (& "$($PSScriptRoot)\Import-AcceleratorCommand.ps1" -Path $_.FullName -DefaultModuleName $module)
            }
        }

        if ($hasFolders) {
            Write-Verbose "Importing command folders in '$($root)\Commands'..."
            $children | where { $_ -is [System.IO.DirectoryInfo] } | foreach {
                Write-Verbose "Scanning directory '$($_.FullName)'..."
                Get-ChildItem $_.FullName -Filter '*.ps1' | foreach {
                    Write-Verbose "Found command file '$($_.Name)'."
                    Write-Output (& "$($PSScriptRoot)\Import-AcceleratorCommand.ps1" -Path $_.FullName)
            	}
            }
        }
    } else {
        Write-Warning "Path '$($root)' contains no commands."
    }
}

return $menu
