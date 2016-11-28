[CmdletBinding(DefaultParameterSetName='List')]
param(
    [Alias('List')]
    [AllowNull()]
    [AllowEmptyCollection()]
    [Parameter(Mandatory=$true, ParameterSetName='List', ValueFromPipeline=$true)]
    [string[]]$ParameterList,

    [Alias('String')]
    [AllowEmptyString()]
    [Parameter(Mandatory=$true, Position=0, ParameterSetName='String')]
    [string]$ParameterString,

    [Parameter()]
    [string[]]$PositionalParameters
)

begin {
    $parameterHash = @{}

    if ($PSCmdlet.ParameterSetName -eq 'String') {
        $parseErrors = $null
        $parameterList = [System.Management.Automation.PSParser]::Tokenize('Verb-Noun ' + $ParameterString, [ref]$parseErrors) |`
                    select -Skip 1 | foreach {
                        $_.Content
                    }

        if ($parseErrors.Count -gt 0) {
            Write-Error "Unable to parse parameter string."
            return
        }
    }

    $parameterName = $null
}

process {
    if ($parameterList.Count -gt 0) {
        for ($i = 0; $i -lt $parameterList.Count; $i += 1) {
            $param = $parameterList[$i]
            Write-Verbose "Param: $param"
            if ($param -match '^\-([A-Za-z]+\:?)$') {
                if ($parameterName) {
                    if ($parameterName.EndsWith(':')) {
                        Write-Error "Invalid syntax '$($parameterName)'."
                    } else {
                        $parameterHash[$parameterName] = $true
                    }
                    $parameterName = $null
                }
                $parameterName = $param -replace '^\-([A-Za-z]+\:?)$', '$1'
                if ($i -eq ($parameterList.Count - 1)) {
                    $parameterReady = $false
                } elseif ($parameterList[$i + 1] -match '^\-([A-Za-z]+\:?)$') {
                    $parameterValue = $true
                    $parameterReady = $true
                } else {
                    $i += 1
                    $parameterValue = $parameterList[$i]
                    $parameterReady = $true
                }
            } elseif ($parameterName) {
                $parameterBool = $false
                if ($parameterName.EndsWith(':')) {
                    if ([bool]::TryParse($param, [ref]$parameterBool)) {
                        $parameterName = $parameterName.Substring(0, $parameterName.Length - 1)
                        $parameterValue = $parameterBool
                        $parameterReady = $true
                    } else {
                        Write-Error "Invalid syntax '$($parameterName)$($param)'."
                        $parameterName = $null
                        $parameterReady = $false
                    }
                } else {
                    $parameterValue = $param
                    $parameterReady = $true
                }
            } elseif ($PositionalParameters.Count -gt 0) {
                $parameterName = $PositionalParameters[0]
                $parameterValue = $param
                $parameterReady = $true
            } else {
                Write-Error "Unable to parse parameter(s) '$(if ($parameterName) { '-' +  $parameterName + ' ' })$($param)'."
                $parameterName = $null
                $parameterReady = $false
            }

            if ($parameterReady) {
                $parameterHash[$parameterName] = $parameterValue
                if ($PositionalParameters.Count -gt 0 -and $PositionalParameters[0] -eq $parameterName) {
                    $PositionalParameters = $PositionalParameters[1..$PositionalParameters.Count]
                } else {
                    $PositionalParameters = @()
                }
                $parameterName = $null
            }
        }
    }
}

end {
    if ($parameterName) {
        if ($parameterName.EndsWith(':')) {
            Write-Error "Invalid syntax '$($parameterName)'."
        } else {
            $parameterHash[$parameterName] = $true
        }
    }

    Write-Output $parameterHash
}
