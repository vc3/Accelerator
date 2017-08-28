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
    $parameterText = $null
    $parameterValue = $null
}

process {
    Write-Verbose "Processing parameter list with $($parameterList.Count) tokens."
    if ($parameterList.Count -gt 0) {
        for ($i = 0; $i -lt $parameterList.Count; $i += 1) {
            $param = $parameterList[$i]
            Write-Verbose "Processing token '$($param)'."
            if ($param -match '^\-([A-Za-z0-9]+\:?)$') {
                Write-Verbose "The token appears to be a parameter name."

                if ($parameterName) {
                    if ($parameterName.EndsWith(':')) {
                        Write-Verbose "Expected a value to follow parameter '$($parameterName)'."
                        Write-Error "Invalid syntax after parameter '$($parameterName)'."
                    } else {
                        Write-Verbose "Storing switch value 'True' for parameter '$($parameterName)'."
                        $parameterHash[$parameterName] = $true
                    }
                    $parameterName = $null
                    $parameterText = $null
                    $parameterValue = $null
                }

                $parameterName = $param -replace '^\-([A-Za-z]+\:?)$', '$1'

                if ($i -eq ($parameterList.Count - 1)) {
                    $parameterReady = $false
                } else {
                    if ($parameterName.EndsWith(':')) {
                        $parameterName = $parameterName.Substring(0, $parameterName.Length - 1)
                    }

                    if ($parameterList[$i + 1] -match '^\-([A-Za-z]+\:?)$') {
                        Write-Verbose "The next token is a parameter name, so assuming switch."
                        $parameterValue = $true
                        $parameterReady = $true
                    } else {
                        $i += 1
                        $parameterText = $parameterList[$i]
                        Write-Verbose "Retrieved value '$($parameterValue)' from the next token."
                        $parameterReady = $true
                    }
                }
            } elseif ($param -match '^\-([A-Za-z0-9]+)\:(.+)$') {
                Write-Verbose "The token appears to be a parameter name and value."

                if ($parameterName) {
                    if ($parameterName.EndsWith(':')) {
                        Write-Verbose "Expected a value to follow parameter '$($parameterName)'."
                        Write-Error "Invalid syntax after parameter '$($parameterName)'."
                    } else {
                        Write-Verbose "Storing switch value 'True' for parameter '$($parameterName)'."
                        $parameterHash[$parameterName] = $true
                    }
                    $parameterName = $null
                    $parameterText = $null
                    $parameterValue = $null
                }

                $parameterName = $param -replace '^\-([A-Za-z0-9]+)\:(.+)$', '$1'
                $parameterText = $param -replace '^\-([A-Za-z0-9]+)\:(.+)$', '$2'
                $parameterReady = $true
            } elseif ($parameterName) {
                $parameterText = $param
                $parameterReady = $true

                if ($parameterName.EndsWith(':')) {
                    $parameterName = $parameterName.Substring(0, $parameterName.Length - 1)
                }
            } elseif ($PositionalParameters.Count -gt 0) {
                $parameterName = $PositionalParameters[0]
                $parameterText = $param
                $parameterReady = $true
            } else {
                Write-Error "Unable to parse parameter(s) '$(if ($parameterName) { '-' +  $parameterName + ' ' })$($param)'."
                $parameterName = $null
                $parameterReady = $false
            }

            if ($parameterReady) {
                if ($parameterText) {
                    $parameterBool = $false
                    $parameterInt = 0

                    if ([bool]::TryParse($parameterText, [ref]$parameterBool)) {
                        $parameterValue = $parameterBool
                    } elseif ([int]::TryParse($parameterText, [ref]$parameterInt)) {
                        $parameterValue = $parameterInt
                    } else {
                        $parameterValue = $parameterText
                    }
                }

                Write-Verbose "Found parameter $($parameterName)=$($parameterValue)"
                $parameterHash[$parameterName] = $parameterValue
                if ($PositionalParameters.Count -gt 0 -and $PositionalParameters[0] -eq $parameterName) {
                    Write-Verbose "Parameter satisfies the next positional parameter."
                    $PositionalParameters = $PositionalParameters[1..$PositionalParameters.Count]
                } else {
                    $PositionalParameters = @()
                }
                $parameterName = $null
                $parameterText = $null
                $parameterValue = $null
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
