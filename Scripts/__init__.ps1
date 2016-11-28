################################################################################
#  Accelerator                                                                 #
#  --------------------------------------------------------------------------  #
#  Author(s): Bryan Matthews                                                   #
#  Company: VC3, Inc.                                                          #
################################################################################

if (-not($PSScriptRoot)) {
    $PSScriptRoot = Split-Path $script:MyInvocation.MyCommand.Path
}

if (-not($PSModulesRoot)) {
    $PSModulesRoot = Join-Path $PSScriptRoot 'Modules'
}

if (-not(Get-Module 'PowerYaml' -ErrorAction 'SilentlyContinue')) {
    Import-Module "$($PSModulesRoot)\PowerYaml\PowerYaml.psd1"
}
