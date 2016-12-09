<#

.SYNOPSIS

Gets a configuration property (if it exists).

.DESCRIPTION

Module: Accelerator
Sequence: 1
Name: GetConfig
Title: Get Configuration Property
Steps:
    - Returns the value of a configuration property (if it exists).

#>
[CmdletBinding(DefaultParameterSetName='Default')]
param(
    [Alias('N')]
    [Parameter(ParameterSetName='Default')]
    [string]$Name,

    [Alias('All')]
    [Parameter(ParameterSetName='ListAll')]
    [switch]$List,

    [Parameter(ValueFromRemainingArguments=$true)]
    $Params
)

if ($List.IsPresent) {
    Get-ConfigurationValue -All | foreach {
        Write-Host "$($_.Name)=$($_.Value)"
    }
} else {
    if (-not($Name)) {
        $name = Read-String -Name 'property name' -Required
    }

    $foundValue = $false

    try {
        $value = Get-ConfigurationValue -Name $name -Required:$false
        $foundValue = $true
    } catch {
        # Do nothing
    }

    if ($foundValue) {
        if ($value -ne $null) {
            Write-Output $value
        }
    } else {
        Write-Host "Did not find property '$($name)'." -ForegroundColor Red
        exit 1
    }
}
