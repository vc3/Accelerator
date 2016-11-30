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
        [int]$MaxAttempts = 3
    )

	$numberOfAttempts = 0

	do {
		$numberOfAttempts += 1

        try {
            Write-Verbose "Attempt #$($numberOfAttempts) to prompt for '$($Name)'."
    		$result = & $Selector
        } catch {
            Write-Host "ERROR: $($_.Exception.Message)"
        }
	}
	while (($result -eq $null) -or ($result -eq "") -and $numberOfAttempts -lt $MaxAttempts)

	if (($result -eq $null) -or ($result -eq "")) {
		throw "Unable to obtain $($Name) from user."
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
        [int]$MaxAttempts = 3
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

    Read-Custom -Name $promptName -MaxAttempts $MaxAttempts -Selector {
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
        [int]$MaxAttempts = 3
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

    Read-Custom -Name $promptName -MaxAttempts $MaxAttempts -Selector {
        Read-Host $promptMessage
    }
}

function Read-Confirmation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,

        [Parameter()]
        [int]$MaxAttempts = 3
    )

    Read-Custom -Name 'confirmation' -MaxAttempts $MaxAttempts -Selector {
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
