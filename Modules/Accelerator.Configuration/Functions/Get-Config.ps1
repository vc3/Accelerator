function Get-Config {
    [CmdletBinding(DefaultParameterSetName='Default')]
    param(
        [Parameter(Mandatory=$true, Position=0, ParameterSetName='Default')]
        [string]$Name,

        [Parameter(ParameterSetName='ListAll')]
        [switch]$All,

        [ValidateSet('Auto', 'String', 'Int32', 'Int64', 'Decimal', 'DateTime', 'Array')]
        [Parameter(ParameterSetName='Default')]
        [string]$Type = 'Auto',

        [Parameter(ParameterSetName='Default')]
        [switch]$Required
    )

    $files = Get-ConfigFile

    if (-not($files)) {
        Write-Error "Unable to find any configuration file path."
        return
    }

    $foundEntry = $false

    $matchedName = $null
    $matchedValue = $null
    $matchedFileName = $null
    $matchedMultiple = $false

    $allValues = @()
    $allValueNames = @()

    $files | ForEach-Object {
        $fileName = $_.Path
        $scope = $_.Scope
        if ($foundEntry) {
            Write-Verbose "Skipping config file '$($fileName)' since setting '$($matchedName)' was already found."
        } else {
            Write-Verbose "Reading config file '$($fileName)'."
            Get-Content $fileName | ForEach-Object {
                if ($_) {
                    $idx = $_.IndexOf('=')
                    $n = $_.Substring(0, $idx).Trim()
                    $v = $_.Substring($idx + 1).Trim()
                    if ($All.IsPresent) {
                        if ($allValueNames -contains $n) {
                            Write-Verbose "Property '$($n)' was already found."
                        } else {
                            Write-Verbose "Returning value for name '$($n)'."

                            $nvp = New-Object 'PSObject'
                            $nvp | Add-Member -Type 'NoteProperty' -Name 'Name' -Value $n
                            $nvp | Add-Member -Type 'NoteProperty' -Name 'Value' -Value $v
                            $nvp | Add-Member -Type 'NoteProperty' -Name 'Scope' -Value $scope

                            $allValues += $nvp
                            $allValueNames += $n
                        }
                    } elseif ($n -eq $Name) {
                        $foundEntry = $true
                        if ($matchedName -and -not($matchedMultiple)) {
                            $matchedMultiple = $true
                            Write-Warning "Configuration property '$($n)' was found more than once, using the first value."
                        } else {
                            Write-Verbose "Found value with name '$($n)'."

                            $matchedName = $n
                            $matchedFileName = $fileName
                            $matchedValue = $v

                            $nvp = New-Object 'PSObject'
                            $nvp | Add-Member -Type 'NoteProperty' -Name 'Name' -Value $n
                            $nvp | Add-Member -Type 'NoteProperty' -Name 'Value' -Value $v
                            $nvp | Add-Member -Type 'NoteProperty' -Name 'Scope' -Value $scope

                            $allValues += $nvp
                            $allValueNames += $n
                        }
                    }
                }
            }
        }
    }

    if ($All.IsPresent) {
        $Type = 'Auto'
    } else {
        if ($Required.IsPresent) {
            Write-Error "Configuration value '$($Name)' was not found."
            return
        }
    }

    $allValues | ForEach-Object {
        if ($Type -eq 'Auto') {
            if ($_.Value) {
                if ($_.Value -match "^\d+$") {
                    $intValue = 0
                    if ([int]::TryParse($_.Value, [ref]$intValue)) {
                        Write-Verbose "Auto-converted value '$($_.Value)' to Int32."
                        $_.Value = $intValue
                    } else {
                        $longValue = 0
                        if ([long]::TryParse($_.Value, [ref]$longValue)) {
                            Write-Verbose "Auto-converted value '$($_.Value)' to Int64."
                            $_.Value = $longValue
                        } else {
                            $decimalValue = [decimal]0
                            if ([decimal]::TryParse($_.Value, [ref]$decimalValue)) {
                                Write-Verbose "Auto-converted value '$($_.Value)' to Decimal."
                                $_.Value = $decimalValue
                            } else {
                                Write-Warning "Unable to parse '$($_.Value)' as Int32, Int64, or Decimal."
                                $_.Value = $_.Value
                            }
                        }
                    }
                } elseif ($_.Value -match "^\d+\.\d+$") {
                    $decimalValue = [decimal]0
                    if ([decimal]::TryParse($_.Value, [ref]$decimalValue)) {
                        Write-Verbose "Auto-converted value '$($_.Value)' to Decimal."
                        $_.Value = $decimalValue
                    } else {
                        Write-Warning "Unable to parse '$($_.Value)' as Decimal."
                    }
                } else {
                    $dateTimeValue = [DateTime]0
                    if ([DateTime]::TryParse($_.Value, [ref]$dateTimeValue)) {
                        Write-Verbose "Auto-converted value '$($_.Value)' to DateTime."
                        $_.Value = $dateTimeValue
                    } elseif ($_.Value -match ',') {
                        $matchedValueTrimmed = $_.Value -replace '\s*,\s*', ','
                        $matchedValueArray = $matchedValueTrimmed.Split(@(','), 'RemoveEmptyEntries')
                        Write-Verbose "Auto-converted value '$($_.Value)' to Array."
                        $_.Value = $matchedValueArray
                    } else {
                        Write-Verbose "Unable to find auto-conversion for value '$($_.Value)'."
                    }
                }
            }
        } elseif ($Type -eq 'String') {
            Write-Verbose "Returning value '$($_.Value)' as String."
        } elseif ($Type -eq 'Decimal') {
            $decimalValue = [decimal]0
            if ([decimal]::TryParse($_.Value, [ref]$decimalValue)) {
                Write-Verbose "Converted value '$($_.Value)' to Decimal."
                $_.Value = $decimalValue
            } else {
                Write-Error "Unable to parse '$($_.Value)' as Decimal."
                return
            }
        } elseif ($Type -eq 'Int64') {
            $longValue = [long]0
            if ([long]::TryParse($_.Value, [ref]$longValue)) {
                Write-Verbose "Converted value '$($_.Value)' to Int64."
                $_.Value = $longValue
            } else {
                Write-Error "Unable to parse '$($_.Value)' as Int64."
                return
            }
        } elseif ($Type -eq 'Int32') {
            $intValue = [int]0
            if ([int]::TryParse($_.Value, [ref]$intValue)) {
                Write-Verbose "Converted value '$($_.Value)' to Int32."
                $_.Value = $intValue
            } else {
                Write-Error "Unable to parse '$($_.Value)' as Int32."
                return
            }
        } elseif ($Type -eq 'DateTime') {
            $dateValue = [DateTime]0
            if ([DateTime]::TryParse($_.Value, [ref]$dateValue)) {
                Write-Verbose "Converted value '$($_.Value)' to DateTime."
                $_.Value = $dateValue
            } else {
                Write-Error "Unable to parse '$($_.Value)' as DateTime."
                return
            }
        } elseif ($Type -eq 'Array') {
            $matchedValueTrimmed = $_.Value -replace '\s*,\s*', ','
            $matchedValueArray = $matchedValueTrimmed.Split(@(','), 'RemoveEmptyEntries')
            Write-Verbose "Converted value '$($_.Value)' to Array."
            $_.Value = $matchedValueArray
        } else {
            Write-Error "Unusupported type '$($Type)'."
            return
        }

        Write-Output $_
    }
}
