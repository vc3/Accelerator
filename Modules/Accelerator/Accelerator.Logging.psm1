################################################################################
#  Accelerator.Logging                                                         #
#  --------------------------------------------------------------------------  #
#  Author(s): Bryan Matthews                                                   #
#  Company: VC3, Inc.                                                          #
################################################################################

if (-not($PSScriptRoot)) {
    $PSScriptRoot = Split-Path $script:MyInvocation.MyCommand.Path
}

#$writeVerbose = $ExecutionContext.InvokeCommand.GetCommand('Write-Verbose', 'Cmdlet')
#$writeDebug = $ExecutionContext.InvokeCommand.GetCommand('Write-Debug', 'Cmdlet')
$writeInformation = $ExecutionContext.InvokeCommand.GetCommand('Write-Information', 'Cmdlet')
$writeWarning = $ExecutionContext.InvokeCommand.GetCommand('Write-Warning', 'Cmdlet')
$writeError = $ExecutionContext.InvokeCommand.GetCommand('Write-Error', 'Cmdlet')

function Write-Information {
	[CmdletBinding()]
	param(
		[Alias('Msg')]
    	[Parameter(Mandatory = $true, Position = 1)]
	    [object]$MessageData,

    	[Parameter(Mandatory = $false, Position = 2)]
		[string[]]$Tags
	)

    try {
        Write-EventLog -LogName 'Application' -Source 'Accelerator' -EntryType Information -EventId 0 -Message $MessageData.ToString() -Category 0
    } catch {
        & $writeWarning "Unable to write informational message to the event log: $($_.Exception.Message)."
    }

	# Call built-in 'Write-Information' cmdlet if available (PSv5).
	if ($writeInformation) {
		& $writeInformation @PSBoundParameters
	} else {
		Write-Host $MessageData
	}
}

function Write-Warning {
	[CmdletBinding()]
	param(
    	[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
	    [string]$Message
	)

    try {
        Write-EventLog -LogName 'Application' -Source 'Accelerator' -EntryType Warning -EventId 0 -Message $Message -Category 0
    } catch {
        & $writeWarning "Unable to write warning message to the event log: $($_.Exception.Message)."
    }

	& $writeWarning @PSBoundParameters
}

function Write-Error {
	[CmdletBinding()]
	param(
    	[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
	    [string]$Message
	)

    try {
        Write-EventLog -LogName 'Application' -Source 'Accelerator' -EntryType Error -EventId 0 -Message $Message -Category 0
    } catch {
        & $writeWarning "Unable to write error message to the event log: $($_.Exception.Message)."
    }

	& $writeError @PSBoundParameters
}
