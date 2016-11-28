param (
    #Every hash table in the array should have a "Name" (string) and "Options" (string array) entry.
    [Parameter(Mandatory=$true)]
    [Hashtable[]]$optionGroups,

    [Parameter(Mandatory=$false)]
    [string]$message,

    [bool]$requireSelection = $true,

    [bool]$displayOptions = $true,

    [bool]$allowSelectByName = $true
)

if (-not($PSScriptRoot)) {
    $PSScriptRoot = Split-Path $script:MyInvocation.MyCommand.Path
}

$allOptions = @()

foreach ($group in $optionGroups)
{
    if($group.ContainsKey("Name") -eq $false)
    {
        throw "Option Hashtable is missing a Name value"
    }

    if($group.ContainsKey("Options") -eq $false)
    {
        throw "Option Hashtable is missing a Options value"
    }

    $allOptions = $allOptions + $group["Options"]
}

if($allOptions.Length -gt 1)
{
    $uniqueOptions = $allOptions | Sort-Object | Get-Unique

    if($uniqueOptions.Length -ne $allOptions.Length){
        foreach ($opt in ($allOptions | Sort-Object))
        {
            write-host $opt
        }

        throw "Duplicate options in prompt"
    }
}

if ($message) {
    Write-Host ""
    Write-Host $message
}

[int]$optSequence = 1
$prompt = ""
$indent = " "

$promptWidth = 80

if($displayOptions -eq $true)
{
    if ($allowSelectByName) {
        $prompt = "Please enter an option number or name"
    } else {
        $prompt = "Please enter an option number"
    }

    $firstGroup = $true

    foreach ($group in $optionGroups)
    {
        Write-Host ""

        if ($optionGroups.Count -gt 1)
        {
            if(($group["Name"] -eq $null) -or ($group["Name"] -eq 0))
            {
                Write-Host "$('-' * $promptWidth)"
            }
            else
            {
                $groupLength = $group["Name"].Length
                $groupPadSize = $promptWidth - ($groupLength + 2)
                Write-Host "$('-' * ([Math]::Floor($groupPadSize / 2))) $($group["Name"]) $('-' * ([Math]::Ceiling($groupPadSize / 2)))"
            }
        }

        Write-Host ""

        $firstGroup = $false

        foreach ($opt in $group["Options"])
        {
            $fc = 'White'

            if ($opt -match '^~.*~$') {
                $fc = 'DarkGray'
                $opt = $opt.Substring(1, $opt.Length - 2)
            }

            [string]$optPrefix = $optSequence

            if($optSequence -lt 10)
            {
                $optPrefix = " " + $optPrefix
            }

            write-host $($indent + "$($optPrefix)) $($opt)") -ForegroundColor $fc

            $optSequence += 1
        }
    }
}
else{
    $prompt = "Please enter selection"
}

if($requireSelection -ne $true){
    $prompt = $prompt + " (press enter to exit)"
}

write-host ""
write-host $(("-" * $promptWidth))
write-host ""
[string]$selection = Read-Host $prompt
[int]$selectionInt = $null

if(($selection.Length -eq 0) -and ($requireSelection -eq $false))
{
    return $null
}
elseif([int32]::TryParse($selection, [ref]$selectionInt) -eq $true)
{
    if(($selectionInt -gt 0) -and ($selectionInt -le $allOptions.length))
    {
        $value = $allOptions[$selectionInt - 1]
        Write-Verbose "Option '$($value)' was selected."
        return $value
    }
}
elseif ($allowSelectByName)
{
    $value = $allOptions | Where-Object {$_ -eq $selection}

    if($value -ne $null)
    {
        return $value
    }
}

Write-Host "Invalid selection: $selection"
Write-Host ""

return (& "$($PSScriptRoot)\Read-MenuOption.ps1" -optionGroups $optionGroups -message $message -displayOptions $displayOptions)
