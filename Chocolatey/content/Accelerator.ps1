function ConvertTo-RightPaddedString {
	[CmdletBinding()]
	param(
	    [Parameter(Mandatory=$true)]
	    [string]$Text,
	
	    [Parameter(Mandatory=$true)]
	    [int]$Width
	)
	
	if ($Text.Length -gt $Width) {
	    $padLength = $Width - $Text.Length
	    return (' ' * $padLength) + $Text
	} else {
	    return $Text
	}
}

function ConvertTo-ParameterHash {
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
}

$PSModuleAutoloadingPreference = 'None'

$ErrorActionPreference = 'Stop'
$InformationPreference = 'Continue'

$here = Split-Path $script:MyInvocation.MyCommand.Path -Parent

$positionalArgs = @('CommandName')

Write-Verbose "Parsing unbound arguments..."
$parsedArgs = $Args | ConvertTo-ParameterHash -PositionalParameters $positionalArgs -ErrorAction Stop

Write-Verbose "Args:`r`n$(($parsedArgs.Keys | foreach { (' ' * 11) + (ConvertTo-RightPaddedString $_ 20) + '=' + $parsedArgs[$_] }) -join "`r`n")"

$parameters = @{}

$commandParameters = @{}

$parameters['CommandParameters'] = $commandParameters

$parameters['UnboundParameters'] = $parsedArgs

if ($parsedArgs.ContainsKey('CommandName')) {
    $parameters['CommandName'] = $parsedArgs['CommandName']
    $parsedArgs.Remove('CommandName') | Out-Null
}

if ($parsedArgs.ContainsKey('y')) {
    $parameters['Confirm'] = $parsedArgs['y']
    $parsedArgs.Remove('Y') | Out-Null
} elseif ($parsedArgs.ContainsKey('yes')) {
    $parameters['Confirm'] = $parsedArgs['yes']
    $parsedArgs.Remove('Yes') | Out-Null
} elseif ($parsedArgs.ContainsKey('confirm')) {
    $parameters['Confirm'] = $parsedArgs['confirm']
    $parsedArgs.Remove('Confirm') | Out-Null
}

if ($parsedArgs.ContainsKey('Verbose')) {
    $parameters['Verbose'] = $parsedArgs['Verbose']
    $parsedArgs.Remove('Verbose') | Out-Null
} elseif ($parsedArgs.ContainsKey('v')) {
    $parameters['Verbose'] = $parsedArgs['v']
    $parsedArgs.Remove('v') | Out-Null
}

if ($parsedArgs.ContainsKey('WorkingDirectory')) {
    $parameters['WorkingDirectory'] = $parsedArgs['WorkingDirectory']
    $parsedArgs.Remove('WorkingDirectory') | Out-Null
} else {
    $parameters['WorkingDirectory'] = (Get-Location).Path
}

if ($parsedArgs.ContainsKey('Interactive')) {
    $parameters['Interactive'] = $parsedArgs['Interactive']
    $parsedArgs.Remove('Interactive') | Out-Null
}

$useStart = $false
if ($parsedArgs.ContainsKey('UseStart')) {
    $useStart = $parsedArgs['UseStart']
    $parsedArgs.Remove('UseStart') | Out-Null
}

$windowTitle = 'Accelerator'
if ($parsedArgs.ContainsKey('WindowTitle')) {
    $windowTitle = $parsedArgs['WindowTitle']
    $parsedArgs.Remove('WindowTitle') | Out-Null
}

$powershellVersion = $powershellVersion
if ($parsedArgs.ContainsKey('PowerShellVersion')) {
    $powershellVersion = $parsedArgs['PowerShellVersion']
    $parsedArgs.Remove('PowerShellVersion') | Out-Null
}

$host.ui.RawUI.WindowTitle = $windowTitle

if ($useStart) {
    $tmpPath = "$([System.IO.Path]::GetTempFileName()).xml"

    Write-Host "Writing parameters to file '$($tmpPath)'..."
    $parameters | Export-Clixml -Path $tmpPath

    $commandString = "
        try {
            `$ErrorActionPreference = 'Stop' ;
            `$host.ui.RawUI.WindowTitle = '$($windowTitle)' ;
            `$global:PSModulesRoot = '$($PSModulesRoot)' ;
            Set-Location '$($PWD.Path)' ;
            Import-Module '$($here)\Accelerator.psd1' ;
            `$parameters = Import-Clixml -Path '$($tmpPath)' ;
            Start-Accelerator @parameters ;
        } catch {
            `$e = `$_.Exception

            do {
                Write-Host `$e.Message -ForegroundColor Red
                Write-Host `$e.StackTrace -ForegroundColor Red

                `$e = `$_.Exception.InnerException
            } while (`$e)

            Read-Host 'Press any key to continue...'
        }
    "

    $arguments = ""

    if ($powershellVersion) {
        $arguments += " -Version $($powershellVersion)"
    }

    $arguments += " -NoProfile"
    $arguments += " -ExecutionPolicy Bypass"
    $arguments += " -Command ""$($commandString)"""

    Write-Host "Starting Accelerator in a new process..."
    Start-Process -FilePath 'powershell' -ArgumentList $arguments
} else {
    if ($powershellVersion) {
        Write-Error "Can't force a particular PowerShell version unless the '-UseStart' flag is used."
        return
    }

    Import-Module "$($here)\Accelerator.psd1"
    Start-Accelerator @parameters
}


