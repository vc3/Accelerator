[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$Path,

    [string]$DefaultModuleName
)

begin {
    if (-not($PSScriptRoot)) {
        $PSScriptRoot = Split-Path $script:MyInvocation.MyCommand.Path
    }

    Import-Module "$($PSScriptRoot)\..\Modules\PowerYaml\PowerYaml.psd1"
}

process {
    $fileName = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    $title = $fileName -replace "_", ' '

    $sequence = $null
    $name = $null
    $module = $DefaultModuleName
    $targetLocation = $null
    $users = '*'
    $disabledReason = ''
    $steps = $null
    $runAsAdmin = $null

    if (-not($DefaultModuleName)) {
        $module = "$(Split-Path (Split-Path $Path -Parent) -Leaf)" -replace '%20', ' '
    }

    $help = Get-Help $Path
    $helpText = $help | select -ExpandProperty 'description' | select -ExpandProperty 'Text'
    if ($helpText) {
        Write-Verbose "Parsing command metadata..."
        $metadata = Get-Yaml -FromString $helpText
        if ($metadata -and $metadata['Sequence']) {
            Write-Verbose "Sequence: $($metadata['Sequence'])"
            $sequence = $metadata['Sequence']
            $sequenceAsInt = 0
            if ([int]::TryParse($sequence, [ref]$sequenceAsInt)) {
                $sequence = $sequenceAsInt
            }
        }
        if ($metadata -and $metadata['Module']) {
            Write-Verbose "Module: $($metadata['Module'])"
            $module = $metadata['Module']
        }
        if ($metadata -and $metadata['Title']) {
            Write-Verbose "Title: $($metadata['Title'])"
            $title = $metadata['Title']
        }
        if ($metadata -and $metadata['Name']) {
            Write-Verbose "Name: $($metadata['Name'])"
            $name = $metadata['Name']
        }
        if ($metadata -and $metadata['TargetLocation']) {
            Write-Verbose "Target Location: $($metadata['TargetLocation'])"
            $targetLocation = $metadata['TargetLocation']
            if ($env:USERDNSDOMAIN -ne $targetLocation) {
                $disabledReason = "should be run within domain '$($targetLocation)'"
            }
        }
        if ($metadata -and $metadata['Users']) {
            $users = $metadata['Users']
            if ($users -is [string] -and $users -ne '*') {
                $users = [array]($users -split ',' | foreach { $_.Trim() })
                Write-Verbose "Users: $($users)"
            } elseif ($users -is [array]) {
                $users = [array]($users | foreach {
                    ($_ -split ',' | foreach { $_.Trim() })
                })
                Write-Verbose "Users: $($users)"
            } else {
                Write-Verbose "Users: $($metadata['Users'])"
                Write-Warning "Unknown type '$($users.GetType().Name)'."
            }
        }
        if ($metadata -and $metadata['Steps'] -and $metadata['Steps'].Count -gt 0) {
            $steps = ($metadata['Steps'] | ForEach-Object { '- ' + $_ }) -join "`r`n"
        } else {
            $steps = $help.Synopsis
        }
        if ($metadata -and $metadata['RunAsAdmin']) {
            if ($metadata['RunAsAdmin'] -is [Boolean]) {
                $runAsAdmin = $metadata['RunAsAdmin']
            } else {
                $runAsAdmin = [bool]::Parse($metadata['RunAsAdmin'])
            }
        } else {
            $runAsAdmin = $false
        }
    }

    $command = New-Object 'PSObject'

    $command | Add-Member -Type NoteProperty -Name 'Path' -Value $Path
    $command | Add-Member -Type NoteProperty -Name 'Module' -Value $module
    $command | Add-Member -Type NoteProperty -Name 'Sequence' -Value $sequence
    $command | Add-Member -Type NoteProperty -Name 'Name' -Value $name
    $command | Add-Member -Type NoteProperty -Name 'Title' -Value $title
    $command | Add-Member -Type NoteProperty -Name 'TargetLocation' -Value $targetLocation
    $command | Add-Member -Type NoteProperty -Name 'Users' -Value $users
    $command | Add-Member -Type NoteProperty -Name 'Steps' -Value $steps
    $command | Add-Member -Type NoteProperty -Name 'DisabledReason' -Value $disabledReason
    $command | Add-Member -Type NoteProperty -Name 'RunAsAdmin' -Value $runAsAdmin

    return $command
}
