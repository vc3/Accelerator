<#

.SYNOPSIS

<COMMAND_DESCRIPTION>

.DESCRIPTION

Module: <COMMAND_MODULE>
Sequence: <COMMAND_SEQUENCE>
Name: <COMMAND_NAME>
Title: <COMMAND_TITLE>
Steps:
    - <STEP_1>
    - <STEP_2>
    - <STEP_3>

#>
[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments=$true)]
    $Params
)
