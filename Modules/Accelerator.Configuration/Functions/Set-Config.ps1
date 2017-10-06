function Set-Config {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$true)]
        [object]$Value,

        [ValidateSet('CurrentCommandRoot', 'CurrentUser', 'LocalMachine')]
        [Parameter(Mandatory=$true)]
        [string]$Scope
    )

    $file = Get-ConfigFile -Scope $Scope -Force

    if (-not($file)) {
        Write-Error "Unable to determine configuration file path for scope '$($Scope)'."
        return
    }

    $fileName = $file.Path

    if (-not(Test-Path $fileName)) {
        if (-not(Test-Path (Split-Path $fileName -Parent))) {
            Write-Verbose "Creating directory '$(Split-Path $fileName -Parent)'."
            mkdir (Split-Path $fileName -Parent) | Out-Null
        }

        Write-Verbose "Creating file '$($fileName)'."
        "" | Out-File $fileName -Encoding 'UTF8'
    }

    if (-not(Test-Path $fileName)) {
        Write-Error "Unable to create file '$($fileName)'."
        return
    }

    $matchedName = $null
    $matchedMultiple = $false

    $originalContent = (Get-Content $fileName) -join "`r`n"

    $modifiedContents = ($originalContent -split "`r`n") | foreach {
        if ($_) {
            $idx = $_.IndexOf('=')
            $n = $_.Substring(0, $idx).Trim()
            $v = $_.Substring($idx + 1).Trim()
            if ($n -eq $Name) {
                if ($matchedName -and -not($matchedMultiple)) {
                    $matchedMultiple = $true
                    Write-Warning "Configuration property '$($n)' was found more than once, replacing the first value."
                    Write-Output $_
                } else {
                    $matchedName = $n
                    Write-Output "$($Name)=$($Value)"
                }
            } else {
                Write-Output $_
            }
        } else {
            Write-Output $_
        }
    }

    try {
        if ($matchedName) {
            $modifiedContents | Out-File $fileName -Encoding 'UTF8'
        } elseif ($originalContent.Trim().Length -eq 0) {
            "$($Name)=$($Value)" | Out-File $fileName -Encoding 'UTF8'
        } else {
            "$($Name)=$($Value)" | Out-File $fileName -Encoding 'UTF8' -Append
        }
    } catch {
        Write-Error "Unable to modify file '$($fileName)': $($_.Exception.Message)"
    }
}
