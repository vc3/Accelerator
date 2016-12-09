################################################################################
#  Accelerator-Configuration                                                   #
#  --------------------------------------------------------------------------  #
#  Author(s): Bryan Matthews                                                   #
#  Company: VC3, Inc.                                                          #
################################################################################

if (-not($PSScriptRoot)) {
    $PSScriptRoot = Split-Path $script:MyInvocation.MyCommand.Path
}

function Get-ConfigurationFilePath {
    [CmdletBinding()]
    param(
    )

    if ($AcceleratorRoot) {
        $rootPath = $AcceleratorRoot
    } else {
        $rootPath = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    }

    $filePath = "$($rootPath)\Accelerator.cfg"

    if (-not(Test-Path $filePath)) {
        if ($Force.IsPresent) {
            Write-Verbose "Forcing use of non-existant 'Accelerator.cfg' file..."
        } elseif (Test-Path "$($rootPath)\$(Split-Path $rootPath -Leaf).cfg") {
            Write-Verbose "Falling back to $(Split-Path $rootPath -Leaf).cfg..."
            $filePath = "$($rootPath)\$(Split-Path $rootPath -Leaf).cfg"
        } else {
            Write-Error "File '$($filePath)' doesn't exist." -Category 'ResourceUnavailable' -ErrorId 42286
            return
        }
    }

    return $filePath
}

function Get-ConfigurationValue {
    [CmdletBinding(DefaultParameterSetName='Default')]
    param(
        [Parameter(Mandatory=$true, ParameterSetName='Default')]
        [string]$Name,

        [Parameter(ParameterSetName='ListAll')]
        [switch]$All,

        [Parameter(ParameterSetName='Default')]
        [type]$Type,

        [Parameter(ParameterSetName='Default')]
        [switch]$Required=$true
    )

    $filePath = Get-ConfigurationFilePath

    $matchedName = $null
    $matchedValue = $null
    $matchedMultiple = $false

    Get-Content $filePath | foreach {
        if ($_) {
            $idx = $_.IndexOf('=')
            $n = $_.Substring(0, $idx).Trim()
            $v = $_.Substring($idx + 1).Trim()
            if ($All.IsPresent) {
                $nvp = New-Object 'PSObject'
                $nvp | Add-Member -Type 'NoteProperty' -Name 'Name' -Value $n
                $nvp | Add-Member -Type 'NoteProperty' -Name 'Value' -Value $v
                Write-Output $nvp
            } elseif ($n -eq $Name) {
                if ($matchedName -and -not($matchedMultiple)) {
                    $matchedMultiple = $true
                    Write-Warning "Configuration property '$($n)' was found more than once, using the first value."
                } else {
                    $matchedName = $n
                    $matchedValue = $v
                }
            }
        }
    }

    if (-not($All.IsPresent)) {
        if (-not($matchedName)) {
            if ($Required.IsPresent) {
                Write-Error "Configuration value '$($Name)' doesn't exist."
            }
            return
        }

        if (-not($Type)) {
            if ($matchedValue) {
                if ($matchedValue -match "^\d+$") {
                    return [int]::Parse($matchedValue)
                } else {
                    $dateTimeValue = [DateTime]0
                    if ([DateTime]::TryParse($matchedValue, [ref]$dateTimeValue)) {
                        return $dateTimeValue
                    } elseif ($matchedValue -match ',') {
                        $matchedValueTrimmed = $matchedValue -replace '\s*,\s*', ','
                        return $matchedValueTrimmed.Split(@(','), 'RemoveEmptyEntries')
                    } else {
                        return $matchedValue
                    }
                }
            } else {
                return ''
            }
        } elseif ($Type -eq [string]) {
            return $matchedValue
        } elseif ($Type -eq [int]) {
            return [int]::Parse($matchedValue)
        } elseif ($Type -eq [DateTime]) {
            return [DateTime]::Parse($matchedValue)
        } elseif ($Type -eq [Array]) {
            $matchedValueTrimmed = $matchedValue -replace '\s*,\s*', ','
            return $matchedValueTrimmed.Split(@(','), 'RemoveEmptyEntries')
        } else {
            Write-Warning "Unusupported type '$($Type.Name)', returning raw string."
            return $matchedValue
        }
    }
}

function Set-ConfigurationValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$true)]
        [object]$Value
    )

    $filePath = Get-ConfigurationFilePath

    $matchedName = $null
    $matchedMultiple = $false

    $modifiedContents = Get-Content $filePath | foreach {
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

    if ($matchedName) {
        $modifiedContents | Out-File $filePath -Encoding UTF8
    } else {
        "$($Name)=$($Value)" | Out-File $filePath -Encoding UTF8 -Append
    }
}

Export-ModuleMember -Function 'Get-ConfigurationValue'
Export-ModuleMember -Function 'Set-ConfigurationValue'
