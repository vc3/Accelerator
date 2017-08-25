################################################################################
#  Accelerator-Logging                                                         #
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
    	[Parameter(Mandatory = $true, Position = 1)]
	    [object]$MessageData,

    	[Parameter(Mandatory = $false, Position = 2)]
		[string[]]$Tags
	)

    try {
        $eventId = 0
        $eventCategory = 0
        $eventMessage = @()

        $eventMessage += $MessageData

        if ($Tags) {
            $eventMessage += ""
            $eventMessage += "Tags: $($Tags -join ', ')"
        }

        Write-EventLog -LogName 'Application' -Source 'Accelerator' -EntryType 'Information' -EventId $eventId -Message ($eventMessage | Out-String) -Category $eventCategory
    } catch {
        & $writeWarning "Unable to write informational message to the event log: $($_.Exception.Message)."
    }

    if ($AcceleratorLogFilePath) {
        "$(($MessageData | Out-String).Trim())" | Out-File $AcceleratorLogFilePath -Append
    }

	# Call built-in 'Write-Information' cmdlet if available (PSv5).
	if ($writeInformation) {
		& $writeInformation @PSBoundParameters
	} else {
		Write-Host ($MessageData | Out-String)
	}
}

<#

.SYNOPSIS

Writes a warning message.

.DESCRIPTION

The Write-Warning cmdlet writes a warning message to the Windows PowerShell host. The response to the warning depends on
 the value of the user's $WarningPreference variable and the use of the WarningAction common parameter.

.LINK

Online Version: http://go.microsoft.com/fwlink/p/?linkid=294033
Write-Debug
Write-Error
Write-Host
Write-Output
Write-Progress
Write-Verbose
about_CommonParameters
about_Preference_Variables

#>
function Write-Warning {
	[CmdletBinding()]
	param(
    	[Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
	    [string]$Message
	)

    try {
        $eventId = 0
        $eventCategory = 0
        $eventMessage = @()

        $eventMessage += $Message

        Write-EventLog -LogName 'Application' -Source 'Accelerator' -EntryType 'Warning' -EventId $eventId -Message ($eventMessage | Out-String) -Category $eventCategory
    } catch {
        & $writeWarning "Unable to write warning message to the event log: $($_.Exception.Message)."
    }

    if ($AcceleratorLogFilePath) {
        "WARNING: $Message" | Out-File $AcceleratorLogFilePath -Append
    }

	& $writeWarning @PSBoundParameters
}

<#

.SYNOPSIS

Writes an object to the error stream.

.DESCRIPTION

The Write-Error cmdlet declares a non-terminating error. By default, errors are sent in the error stream to the host pro
gram to be displayed, along with output.
To write a non-terminating error, enter an error message string, an ErrorRecord object, or an Exception object.  Use the
 other parameters of Write-Error to populate the error record.
Non-terminating errors write an error to the error stream, but they do not stop command processing. If a non-terminating
 error is declared on one item in a collection of input items, the command continues to process the other items in the c
ollection.
To declare a terminating error, use the Throw keyword. For more information, see about_Throw (http://go.microsoft.com/fw
link/?LinkID=145153).

.LINK

Online Version: http://go.microsoft.com/fwlink/p/?linkid=294028
Write-Debug
Write-Host
Write-Output
Write-Progress
Write-Verbose
Write-Warning

#>
function Write-Error {
    [CmdletBinding(DefaultParameterSetName='NoException')]
    param(
    	[Parameter(Mandatory=$true, Position=0, ParameterSetName='NoException')]
    	[Parameter(ParameterSetName='WithException')]
    	[string]$Message,

    	[Parameter(ParameterSetName='NoException')]
    	[Parameter(ParameterSetName='WithException')]
    	[System.Management.Automation.ErrorCategory]$Category,

    	[Parameter(ParameterSetName='NoException')]
    	[Parameter(ParameterSetName='WithException')]
    	[Parameter(ParameterSetName='ErrorRecord')]
    	[String]$CategoryActivity,

    	[Parameter(ParameterSetName='NoException')]
    	[Parameter(ParameterSetName='WithException')]
    	[Parameter(ParameterSetName='ErrorRecord')]
    	[String]$CategoryReason,

    	[Parameter(ParameterSetName='NoException')]
    	[Parameter(ParameterSetName='WithException')]
    	[Parameter(ParameterSetName='ErrorRecord')]
    	[String]$CategoryTargetName,

    	[Parameter(ParameterSetName='NoException')]
    	[Parameter(ParameterSetName='WithException')]
    	[Parameter(ParameterSetName='ErrorRecord')]
    	[String]$CategoryTargetType,

    	[Parameter(ParameterSetName='NoException')]
    	[Parameter(ParameterSetName='WithException')]
    	[String]$ErrorId,

    	[Parameter(ParameterSetName='NoException')]
    	[Parameter(ParameterSetName='WithException')]
    	[Parameter(ParameterSetName='ErrorRecord')]
    	[String]$RecommendedAction,

    	[Parameter(ParameterSetName='NoException')]
    	[Parameter(ParameterSetName='WithException')]
    	[Object]$TargetObject,

    	[Parameter(Mandatory=$true, ParameterSetName='ErrorRecord')]
    	[System.Management.Automation.ErrorRecord]$ErrorRecord,

    	[Parameter(Mandatory=$true, ParameterSetName='WithException')]
    	[Exception]$Exception
    )

    try {
        if ($ErrorRecord) {
            if (-not($Category)) {
                $category = $ErrorRecord.CategoryInfo.Category
            }

            if (-not($CategoryActivity)) {
                $categoryActivity = $ErrorRecord.CategoryInfo.Activity
            }

            if (-not($CategoryReason)) {
                $categoryReason = $ErrorRecord.CategoryInfo.Reason
            }

            if (-not($CategoryTargetName)) {
                $categoryTargetName = $ErrorRecord.CategoryInfo.TargetName
            }

            if (-not($CategoryTargetType)) {
                $categoryTargetType = $ErrorRecord.CategoryInfo.TargetType
            }

            if (-not($ErrorId)) {
                $errorId = $ErrorRecord.FullyQualifiedErrorId
            }

            if (-not($RecommendedAction) -and $ErrorRecord.ErrorDetails) {
                $recommendedAction = $ErrorRecord.ErrorDetails.RecommendedAction
            }

            if (-not($TargetObject)) {
                $targetObject = $ErrorRecord.TargetObject
            }

            if ($ErrorRecord.Exception) {
                if (-not($Exception)) {
                    $exception = $ErrorRecord.Exception
                }

                if (-not($Message)) {
                    $message = $exception.Message
                }
            }
        }

        $eventId = 0

        $eventMessage = @()

        $eventCategory = 0

        $includesMessageDetails = $false

        if ($message) {
            $eventMessage += $message
        } else {
            $eventMessage += 'An unknown error occurred.'
        }

        if ($Category) {
            if (-not($includesMessageDetails)) {
                $eventMessage += ""
                $includesMessageDetails = $true
            }
            $eventMessage += "Category: $($category)"
        }

        if ($categoryActivity) {
            if (-not($includesMessageDetails)) {
                $eventMessage += ""
                $includesMessageDetails = $true
            }
            $eventMessage += "Category Activity: $($categoryActivity)"
        }

        if ($categoryReason) {
            if (-not($includesMessageDetails)) {
                $eventMessage += ""
                $includesMessageDetails = $true
            }
            $eventMessage += "Category Reason: $($categoryReason)"
        }

        if ($categoryTargetName) {
            if (-not($includesMessageDetails)) {
                $eventMessage += ""
                $includesMessageDetails = $true
            }
            $eventMessage += "Category Target Name: $($categoryTargetName)"
        }

        if ($categoryTargetType) {
            if (-not($includesMessageDetails)) {
                $eventMessage += ""
                $includesMessageDetails = $true
            }
            $eventMessage += "Category Target Type: $($categoryTargetType)"
        }

        if ($errorId) {
            if (-not($includesMessageDetails)) {
                $eventMessage += ""
                $includesMessageDetails = $true
            }
            $eventMessage += "Error ID: $($errorId)"
        }

        if ($recommendedAction) {
            if (-not($includesMessageDetails)) {
                $eventMessage += ""
                $includesMessageDetails = $true
            }
            $eventMessage += "Recommended Action: $($recommendedAction)"
        }

        if ($exception) {
            if (-not($includesMessageDetails)) {
                $eventMessage += ""
                $includesMessageDetails = $true
            }
            $eventMessage += "Exception: $($exception.Message)"
            if ($exception.StackTrace) {
                $eventMessage += "$($exception.StackTrace)"
            }
        }

        Write-EventLog -LogName 'Application' -Source 'Accelerator' -EntryType 'Error' -EventId $eventId -Message ($eventMessage | Out-String) -Category $eventCategory
    } catch {
        & $writeWarning "Unable to write error message to the event log: $($_.Exception.Message)."
    }

    if ($AcceleratorLogFilePath) {
        if ($Message) {
            "ERROR: $Message" | Out-File $AcceleratorLogFilePath -Append
        } elseif ($Exception) {
            "ERROR: $($Exception.Message)" | Out-File $AcceleratorLogFilePath -Append
        } elseif ($ErrorRecord -and $ErrorRecord.Exception) {
            "ERROR: $($ErrorRecord.Exception.Message)" | Out-File $AcceleratorLogFilePath -Append
        } else {
            "ERROR: An unknown error occurred." | Out-File $AcceleratorLogFilePath -Append
        }
    }

	& $writeError @PSBoundParameters
}
