<#

.SYNOPSIS

Sets a configuration property.

.DESCRIPTION

Module: Accelerator
Sequence: 1
Name: SetConfig
Title: Set Configuration Property
Steps:
    - Sets the value of a configuration property.

#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$Name,

    [Parameter()]
    [object]$Value,

    [Parameter(ValueFromRemainingArguments=$true)]
    $Params
)

if (-not($Name)) {
    if ($AcceleratorInteractive) {
        $name = Read-String -Name 'property name' -Required
    } else {
        Write-Error "Parameter '-Name' is required."
    }
}

if (-not($Value)) {
    if ($AcceleratorInteractive) {
        $value = Read-String -Name 'property value' -Required
    } else {
        Write-Error "Parameter '-Value' is required."
    }
}

Set-ConfigurationValue -Name $name -Value $value
