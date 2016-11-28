<#

.SYNOPSIS

<COMMAND_DESCRIPTION>

.DESCRIPTION

Sequence: <COMMAND_SEQUENCE>
Code: <COMMAND_CODE>
Title: <COMMAND_TITLE>
Steps:
    - <STEP_1>
    - <STEP_2>
    - <STEP_3>

#>
[CmdletBinding()]
param(
    [switch]$Interactive,

    [Parameter(ValueFromRemainingArguments=$true)]
    $Params
)
