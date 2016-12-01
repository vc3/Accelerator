################################################################################
#  Accelerator.Host                                                            #
#  --------------------------------------------------------------------------  #
#  Author(s): Bryan Matthews                                                   #
#  Company: VC3, Inc.                                                          #
################################################################################

if (-not($PSScriptRoot)) {
    $PSScriptRoot = Split-Path $script:MyInvocation.MyCommand.Path
}

function Read-Custom {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$true)]
        [scriptblock]$Selector,

        [Parameter()]
        [switch]$Required,

        [Parameter()]
        [int]$MaxAttempts = 1
    )

	$numberOfAttempts = 0

	do {
		$numberOfAttempts += 1

        if ($Required.IsPresent) {
            try {
        		$result = & $Selector
            } catch {
                Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
            }
        } else {
    		$result = & $Selector
        }
	}
	while ($Required.IsPresent -and (-not($result -is [bool]) -and ($result -eq $null -or $result -eq "")) -and $numberOfAttempts -lt $MaxAttempts)

	if ($Required.IsPresent -and (-not($result -is [bool]) -and ($result -eq $null -or $result -eq ""))) {
		Write-Error "Unable to obtain $($Name) from user."
        return
	}

	return $result
}

function Read-Option {
    [CmdletBinding(DefaultParameterSetName='CustomMessage')]
    param(
        [Parameter(Mandatory=$true, ParameterSetName='CustomMessage')]
        [string]$Message,

        [Parameter(ParameterSetName='NamedObject')]
        [string]$Name,

        [Parameter(Mandatory=$true)]
        [string[]]$ValidValues,

        [Parameter()]
        [switch]$Required=$true,

        [Parameter()]
        [int]$MaxAttempts = 1
    )

    if ($Name) {
        $promptName = $Name
    } else {
        $promptName = 'option'
    }

    if ($Message) {
        $promptMessage = $Message
    } else {
        $promptMessage = "Please select a $($Name)"
    }

    Read-Custom -Name $promptName -Required:$Required.IsPresent -MaxAttempts $MaxAttempts -Selector {
        $value = Read-Host "$promptMessage (options: $($ValidValues -join ', '))"
        if ($ValidValues -contains $value) {
            return $value
        }
    }
}

function Read-String {
    [CmdletBinding(DefaultParameterSetName='CustomMessage')]
    param(
        [Parameter(Mandatory=$true, ParameterSetName='CustomMessage')]
        [string]$Message,

        [Parameter(ParameterSetName='NamedObject')]
        [string]$Name,

        [Parameter()]
        [switch]$Required,

        [Parameter()]
        [int]$MaxAttempts = 1
    )

    if ($Message) {
        $promptMessage = $Message
    } else {
        $promptMessage = "Please select a $($Name)"
    }

    if ($Name) {
        $promptName = $Name
    } else {
        $promptName = 'string'
    }

    Read-Custom -Name $promptName -Required:$Required.IsPresent -MaxAttempts $MaxAttempts -Selector {
        Read-Host $promptMessage
    }
}

function Read-Confirmation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [Parameter()]
        [switch]$Required,

        [Parameter()]
        [int]$MaxAttempts = 1
    )

    Read-Custom -Name 'confirmation' -Required:$Required.IsPresent -MaxAttempts $MaxAttempts -Selector {
        $confirmation = Read-Host "$Message (y/n)"
        if ($confirmation) {
            if ($confirmation -eq 'y') {
                return $true
            } else {
                return $false
            }
        }
    }
}
