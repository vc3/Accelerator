function GetApplication {
	param(
		[Parameter(Mandatory=$true, HelpMessage="The name of the application.")]
		[string]$Name,
		[Parameter(Mandatory=$false, HelpMessage="The type of information to return.")]
		[ValidateSet("Object", "Path")]
		[string]$ResultType="Object"
	)

	# Get command information for the given executable program.
	$info = Get-Command -CommandType Application -Name $Name -ErrorAction SilentlyContinue

	if ($info -is [Array]) {
		# Allow gcm output to go to standard out before raising an error.
		gcm -commandType Application -name $Name -ErrorAction SilentlyContinue | %{
			Get-Item $_.Definition
		}
		write-output ""
		throw "'$Name' is ambiguous. $($info.Length) matches: $info"
	}

	if (!$info) {
		throw "Could not locate ""$Name"" - please verify that your user or system path includes it."
	}

	if ($ResultType -eq "Path") {
		return $info.Definition
	}
	else {
		return $info
	}
}

function EscapeArgumentIfNeeded
{
	param(
		[Parameter(HelpMessage="The argument value.")]
		[string]$Value
	)

	$isEscaped = $false
	for ($i = 0; $i -lt $Value.Length; $i += 1) {
		$c = $Value[$i]
		if ($c -eq """") {
			$isEscaped = !$isEscaped
		}
		elseif ($c -eq " " -or $c -eq "`t") {
			if (!$isEscaped) {
				Write-Verbose "Escaping argument $Value"
				Write-Output """$Value"""
				return
			}
		}
	}
	
	Write-Output $Value
}

#ifdef TEST
<#

function TestEscape
{
	param(
		[Parameter(Mandatory=$true, HelpMessage="The argument value.")]
		[string]$Value,
		[boolean]$shouldEscape
	)

	#Write-Host "Input: $Value"
	$escaped = EscapeArgumentIfNeeded -Value $Value
	#Write-Host "Result: $escaped"
	if ($shouldEscape -and $Value -eq $escaped) {
		Write-Host "Should have been escaped: $Value"
	}
	if (!$shouldEscape -and $Value -ne $escaped) {
		Write-Host "Should NOT have been escaped: $Value"
	}
}

TestEscape -Value "Foo Bar" -shouldEscape $true
TestEscape -Value "Foo	Bar" -shouldEscape $true
TestEscape -Value """Foo Bar""" -shouldEscape $false
TestEscape -Value "FooBar" -shouldEscape $false
TestEscape -Value "value=""Foo Bar""" -shouldEscape $false

#>
#endif

# Taken from Chocolatey
function RunProcessAsAdmin {
    [CmdletBinding()]
    param(
        [string] $statements,
        [string] $exeToRun = 'powershell',
        [ValidateSet('x86', 'x64')]
        [string] $powershellVersion = 'x64',
        [boolean] $minimized = $true,
        [switch] $noSleep,
        $validExitCodes = @(0),
        [boolean]$EnsureSuccess=$true,
        [ValidateSet("None", "ExitCode")]
        [string]$ReturnType="None"
    )

    $wrappedStatements = $statements;
    if ($exeToRun -eq 'powershell') {
        $exeToRun = "$($env:windir)\System32\WindowsPowerShell\v1.0\powershell.exe"

        if ($powershellVersion -eq 'x86') {
            $exeToRun = "$($env:windir)\syswow64\WindowsPowerShell\v1.0\powershell.exe"
        }

        if (!$statements.EndsWith(';')){$statements = $statements + ';'}

        $wrappedStatements = "-NoProfile -ExecutionPolicy unrestricted -Command `"try{$statements start-sleep 6;}catch{write-error `'That was not sucessful`';`$_.Exception.Message | out-file `'$processDir\error.log`';start-sleep 8;throw;}`""
        if ($noSleep) {
            $wrappedStatements = "-NoProfile -ExecutionPolicy unrestricted -Command `"try{$statements}catch{write-error `'That was not sucessful`';`$_.Exception.Message | out-file `'$processDir\error.log`';throw;}`""
        }
    }

    $psi = new-object System.Diagnostics.ProcessStartInfo;
    $psi.FileName = $exeToRun;
    if ($wrappedStatements -ne '') {
        $psi.Arguments = "$wrappedStatements";
    }

    if ([Environment]::OSVersion.Version -ge (new-object 'Version' 6,0)){
        $psi.Verb = "runas";
    }

    $psi.WorkingDirectory = get-location;

    if ($minimized) {
        $psi.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Minimized;
    }

    $s = [System.Diagnostics.Process]::Start($psi);
    $s.WaitForExit();

    if ($EnsureSuccess) {
        if ($validExitCodes -notcontains $s.ExitCode) {
            $errorMessage = "[ERROR] Running $exeToRun with $statements was not successful. Exit code was `'$($s.ExitCode)`'."
            Write-Error $errorMessage
            throw $errorMessage
        }
    }

    if ($ReturnType -eq "ExitCode") {
        return $s.ExitCode
    }
}


function Invoke-ApplicationFromArgsAndReturnOutput {
	<#
	    .Synopsis
	    Invokes the given executable and arguments and returns the output.
	    .Example
	    Invoke-ApplicationFromArgsAndReturnOutput notepad C:\NewFile.txt
	    exeoutput notepad C:\NewFile.txt
	    NAME: Invoke-ApplicationFromArgsAndReturnOutput
	    AUTHOR: Bryan Matthews
	    KEYWORDS:
	#>
	
	# TODO: Should EnsureSuccess be true?
	Invoke-ApplicationWithOptions -ArgsArray $args -EnsureSuccess $false -ReturnType Output
}

function Invoke-ApplicationWithOptions {
	param (
		[Parameter(Mandatory=$true)]
		[System.Object[]]$ArgsArray,
	
		[Parameter(Mandatory=$true)]
		[boolean]$EnsureSuccess,
	
		[Parameter(Mandatory=$true)]
		[ValidateSet('None', 'ExitCode', 'Output')]
		[string]$ReturnType,
	
		[ValidateSet('Verbose', 'On', 'Off')]
		[string]$Logging='Verbose',
	
		[switch]$RunAsAdmin
	)
	
	
	if ($ArgsArray.Length -lt 1) {
	    throw "First argument must be the name of an executable"
	}
	
	$name = $ArgsArray[0]
	$appInfo = GetApplication $name
	
	if ($ArgsArray.Length -gt 1) {
	    $arguments = (($ArgsArray[1..$ArgsArray.Length] | Where-Object { $_.Length -gt 0 } | ForEach-Object { EscapeArgumentIfNeeded $_ }) -join " ")
	}
	else {
	    $arguments = " "
	}
	
	Invoke-Application -FilePath $appInfo.Definition -Arguments $arguments -EnsureSuccess $EnsureSuccess -ReturnType $ReturnType -Logging $Logging -RunAsAdmin:$RunAsAdmin
}

function Invoke-Application {
	param(
	    [Parameter(Mandatory=$true)]
	    [string]$FilePath,
	
	    [Parameter(Mandatory=$true)]
	    [string]$Arguments,
	
	    [Parameter(Mandatory=$true)]
	    [boolean]$EnsureSuccess,
	
	    [Parameter(Mandatory=$true)]
	    [ValidateSet('None', 'ExitCode', 'Output')]
	    [string]$ReturnType,
	
	    [ValidateSet('Verbose', 'On', 'Off')]
	    [string]$Logging='Verbose',
	
	    [switch]$SuppressInconsistentErrorLogging,
	
	    [switch]$RunAsAdmin
	)
	
	if (!$FilePath) {
	    throw "First argument must be the name of an executable!"
	}
	
	if (!(Test-Path $FilePath)) {
	    throw "Executable path ""$FilePath"" does not exist!"
	}
	
	if ($Logging -eq 'On') {
	    Write-Host ">> $FilePath $Arguments"
	}
	elseif ($Logging -eq 'Verbose') {
	    Write-Verbose ">> $FilePath $Arguments"
	}
	elseif ($Logging -ne 'Off') {
	    throw "Unknown logging mode '$($Logging)'."
	}
	
	if ($ReturnType -eq "Output") {
	    if ($RunAsAdmin.IsPresent -and (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))) {
	        throw "Cannot elevate permissions and capture output."
	    }
	
	    $process = New-Object System.Diagnostics.Process
	
	    $process.StartInfo.FileName = $FilePath
	    $process.StartInfo.WorkingDirectory = (Get-Location).Path
	    $process.StartInfo.Arguments = $Arguments
	    $process.StartInfo.UseShellExecute = $false
	    $process.StartInfo.RedirectStandardOutput = $true
	    $process.StartInfo.RedirectStandardError = $true
	
	    # start the process and begin reading stdout and stderr
	    [void]$process.Start()
	
	    $outStream = $process.StandardOutput
	    $out = $outStream.ReadToEnd()
	
	    $errStream = $process.StandardError
	    $err = $errStream.ReadToEnd()
	
	    # Shutdown async read events
	    $exitCode = $process.ExitCode
	    $process.Close()
	
	    if ($err.Length -ne 0 -and ($exitCode -ne 0 -or !$SuppressInconsistentErrorLogging)) {
	        Write-Host $err.ToString() -ForegroundColor Red
	    }
	
	    if ($EnsureSuccess -eq $true) {
	        if($exitCode -ne 0) {
	            throw "$FilePath $Arguments --> failed with exit code $exitCode"
	        }
	    }
	
	    return $out
	}
	elseif ($RunAsAdmin.IsPresent -and (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))) {
	    RunProcessAsAdmin -statements $Arguments -exeToRun $FilePath -EnsureSuccess $EnsureSuccess -ReturnType $ReturnType
	}
	else {
	    $process = Start-Process -FilePath "$FilePath" -ArgumentList $Arguments -NoNewWindow -Wait -PassThru
	
	    if ($EnsureSuccess -eq $true) {
	        if($process.ExitCode -ne 0) {
	            throw "$FilePath $Arguments --> failed with exit code $($process.ExitCode)"
	        }
	    }
	
	    if ($ReturnType -eq "ExitCode") {
	        return $process.ExitCode
	    }
	}
}

function Invoke-ApplicationFromArgsAndPassThrough {
	<#
		.Synopsis
		Invokes the given executable and arguments and passes along the output.
		.Example
		Invoke-ApplicationFromArgsAndPassThrough notepad C:\NewFile.txt
	    exe notepad C:\NewFile.txt
		NAME: Invoke-ApplicationFromArgsAndPassThrough
		AUTHOR: Bryan Matthews
		KEYWORDS:
	#>
	
	Invoke-ApplicationWithOptions -ArgsArray $args -EnsureSuccess $true -ReturnType None
}

function Invoke-ApplicationFromArgsAndReturnExitCode {
	<#
		.Synopsis
		Invokes the given executable and arguments and returns the exit code.
		.Example
		Invoke-ApplicationFromArgsAndReturnExitCode notepad C:\NewFile.txt
	    exeexitcode notepad C:\NewFile.txt
		NAME: Invoke-ApplicationFromArgsAndReturnExitCode
		AUTHOR: Bryan Matthews
		KEYWORDS:
	#>
	
	Invoke-ApplicationWithOptions -ArgsArray $args -EnsureSuccess $false -ReturnType ExitCode
}

Export-ModuleMember -Function Invoke-Application
Export-ModuleMember -Function Invoke-ApplicationFromArgsAndPassThrough
Export-ModuleMember -Function Invoke-ApplicationFromArgsAndReturnExitCode
Export-ModuleMember -Function Invoke-ApplicationFromArgsAndReturnOutput
Export-ModuleMember -Function Invoke-ApplicationWithOptions
