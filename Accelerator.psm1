################################################################################
#  Accelerator                                                                 #
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
        [string]$message
    )

    $confirmation = Read-Host "$message (y/n)"
    if ($confirmation) {
        if ($confirmation -eq 'y') {
            return $true
        } else {
            return $false
        }
    }
}
