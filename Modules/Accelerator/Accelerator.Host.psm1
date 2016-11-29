################################################################################
#  Accelerator.Host                                                            #
#  --------------------------------------------------------------------------  #
#  Author(s): Bryan Matthews                                                   #
#  Company: VC3, Inc.                                                          #
################################################################################

if (-not($PSScriptRoot)) {
    $PSScriptRoot = Split-Path $script:MyInvocation.MyCommand.Path
}

function Read-Confirmation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message
    )

    $confirmation = Read-Host "$Message (y/n)"
    if ($confirmation) {
        if ($confirmation -eq 'y') {
            return $true
        } else {
            return $false
        }
    }
}
