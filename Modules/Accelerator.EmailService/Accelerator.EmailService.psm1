################################################################################
#  Accelerator.EmailService v0.1.0                                             #
#                                                                              #
#  --------------------------------------------------------------------------  #
#  Author(s): Bryan Matthews                                                   #
#  Company: VC3, Inc.                                                          #
################################################################################

if (-not($PSScriptRoot)) {
    $PSScriptRoot = Split-Path $script:MyInvocation.MyCommand.Path
}

Write-Verbose "Scanning directory '$($PSScriptRoot)\Functions'..."
foreach ($function in [array](Get-ChildItem "$($PSScriptRoot)\Functions" -Filter *.ps1)) {
    Write-Verbose "Importing '$([System.IO.Path]::GetFileName($function.FullName))'..."
    . $function.FullName
}

Import-Module "$($PSScriptRoot)\..\Accelerator.Configuration\Accelerator.Configuration.psd1"
Import-Module "$($PSScriptRoot)\..\Accelerator.ServiceConnector\Accelerator.ServiceConnector.psd1"
