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


function Read-MenuOption {
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
	
	return (Read-MenuOption -optionGroups $optionGroups -message $message -displayOptions $displayOptions)
}

function Start-Accelerator {
	[CmdletBinding()]
	param(
	    [Parameter(Position=0)]
	    [string]$CommandName,
	
	    [switch]$Interactive,
	
	    [string]$WorkingDirectory,
	
	    [Alias('y')]
	    [Alias('yes')]
	    [switch]$Confirm,
	
	    [Hashtable]$CommandParameters,
	
	    [Hashtable]$UnboundParameters
	)
	
	if ($UnboundParameters.Keys.Count -gt 0) {
	    Write-Warning "Unbound Parameters:`r`n$(($UnboundParameters.Keys | foreach { (' ' * 11) + $_ + '=' + $UnboundParameters[$_] }) -join "`r`n")"
	}
	
	$PSModuleAutoloadingPreference = 'None'
	
	$ErrorActionPreference = 'Stop'
	$InformationPreference = 'Continue'
	
	if (-not($PSScriptRoot) -or $PSScriptRoot -ne (Split-Path $script:MyInvocation.MyCommand.Path -Parent)) {
	    Write-Verbose "Setting 'PSScriptRoot' variable since it isn't automatically set by the runtime..."
	    $PSScriptRoot = Split-Path $script:MyInvocation.MyCommand.Path -Parent
	}
	
	if (-not($CommandName) -and -not($Interactive.IsPresent)) {
	    throw "A command must be specified when run in non-interactive mode."
	}
	
	if (Test-Path "$($PSScriptRoot)\Accelerator.version") {
	    $version = (Get-Content "$($PSScriptRoot)\Accelerator.version").Trim()
	} elseif (Test-Path "$($PSScriptRoot)\..\Accelerator.nuspec") {
	    $version = ([xml](Get-Content "$($PSScriptRoot)\..\Accelerator.nuspec")).package.metadata.version.Trim()
	} else {
	    $version = '???'
	}
	
	Write-Host "Accelerator v$($version)"
	Write-Host ""
	
	$matchedCommandFile = $null
	$matchedCommandNames = @()
	
	$commands = [array](Get-AcceleratorCommand)
	
	if ($CommandName) {
	    Write-Verbose "Attempting to match command '$($CommandName)'..."
	    $commandObjects = [array]($commands | where {
	        if (($_.Name -and $CommandName -eq $_.Name) -or $_.Title -like $CommandName) {
	            Write-Verbose "Command '$($_.Title)' ($($_.Name)) matches!"
	            return $true
	        }
	    })
	
	    if ($commandObjects.Count -gt 1) {
	        Write-Error "Text '$($CommandName)' matched multiple commands: $(($commandObjects | select -ExpandProperty Title) -join ', ')"
	        return
	    } elseif ($commandObjects.Count -eq 0) {
	        Write-Host ""
	        Write-Warning "Unable to find command matching '$($CommandName)'."
	        Write-Host ""
	    }
	}
	
	# Run commands
	while ($true) {
	    $runCommand = $true
	
	    if ($commandObjects.Count -eq 1) {
	        $commandObject = $commandObjects[0]
	    } elseif ($Interactive.IsPresent) {
	        $commandMenu = [array]($commands | Group-Object -Property 'Module' | where {
	            ([array]($_.Group)).Count -gt 0
	        }| foreach {
	            $menuGroup = @{}
	
	            $menuGroup['Name'] = $_.Name
	
	            $menuGroup['Options'] = [array]($_.Group | sort {
	                if ($_.Sequence -is [int]) {
	                    $_.Sequence
	                } else {
	                    [int]::MaxValue
	                }
	            } | foreach {
	                if ($_.DisabledReason) {
	                    "~$($_.Title)~"
	                } else {
	                    $_.Title
	                }
	            })
	
	            return $menuGroup
	        })
	
	        if ($commandMenu.Count -eq 0) {
	            throw "No available commands."
	        }
	
	        $option = Read-MenuOption -optionGroups $commandMenu -requireSelection $false -allowSelectByName $false
	
	        if (-not $option) {
	            break
	        }
	
	        if ($option -match '^~.*~$') {
	            $commandTitle = $option.Substring(1, $option.Length - 2)
	        } else {
	            $commandTitle = $option
	        }
	
	        $commandObjects = [array]($commands | where {
	            if ($_.Title -eq $commandTitle) {
	                Write-Verbose "Command '$($_.Title)' ($($_.Name)) matches!"
	                return $true
	            }
	        })
	
	        $commandObject = $commandObjects[0]
	
	        if ($option -match '^~.*~$') {
	            Write-Warning "Command '$($commandObject.Title)' $($commandObject.DisabledReason)."
	            if (-not($Confirm.IsPresent) -and -not(Read-Confirmation -Message "Continue anyway?")) {
	                Write-Host ""
	                Write-Host "Select a different command?"
	                Write-Host ""
	                continue
	            }
	        }
	
	        if (-not(Test-Path $commandObject.Path)) {
	            throw "File '$($commandObject.Path)' doesn't exist."
	        }
	
	        Write-Host "`r`n$($commandObject.Title)`r`n$('-' * ($commandObject.Title.Length))`r`n`r`n$($commandObject.Steps)`r`n"
	
		    if (-not($Confirm.IsPresent) -and -not(Read-Confirmation -Message "Continue")) {
	            Write-Host ""
	            Write-Host "Command aborted."
	            Write-Host ""
	            $runCommand = $false
	        }
	    } else {
	        throw "Command '$($CommandName)' couldn't to be found."
	    }
	
	    if ($runCommand) {
	
	        if ($Interactive.IsPresent) {
	            Write-Host ""
	        }
	
	        Write-Host "Running command '$($commandObject.Title)'..."
	        Write-Host ""
	
	        # if (-not($Interactive.IsPresent)) {
	        #     Write-Progress -Activity "Command '$($commandObject.Title)'" -Status 'Running command...' -PercentComplete 30
	        # }
	
	        try {
	            $PSScriptRoot = Split-Path $commandObject.Path -Parent
	            & $commandObject.Path @CommandParameters
	        #} catch {
	        #    Write-Host ""
	        #    Write-Error "Error: $($_.Exception.Message)"
	        } finally {
	            $PSScriptRoot = Split-Path $script:MyInvocation.MyCommand.Path -Parent
	        }
	
	        Write-Host ""
	    }
	
	    if (($CommandName -and $commandObject) -or -not($Interactive.IsPresent)) {
	        break
	    }
	
	    $commandObjects = $null
	
	    if (-not(Read-Confirmation -Message "Would you like to run another command?")) {
	        break
	    }
	}
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

function Get-AcceleratorCommand {
	[CmdletBinding()]
	param(
	    [string]$AcceleratorPath
	)
	
	if (-not($PSScriptRoot)) {
	    $PSScriptRoot = Split-Path $script:MyInvocation.MyCommand.Path
	}
	
	if ($AcceleratorPath) {
	    $pathRoots = [array]($AcceleratorPath -split ';')
	} else {
	    $pathRoots = Get-AcceleratorPath -AsArray
	}
	
	foreach ($root in $pathRoots) {
	    if (Test-Path "$($root)\Commands") {
	        Write-Verbose "Scanning directory '$($root)\Commands'..."
	
	        $children = [array](Get-ChildItem "$($root)\Commands")
	
	        $hasFiles = $false
	        $hasFolders = $false
	
	        foreach ($c in $children) {
	            Write-Verbose "Checking child item '$($c.Name)'..."
	            if ($c -is [System.IO.DirectoryInfo]) {
	                if (Get-ChildItem $c.FullName -Filter '*.ps1') {
	                    Write-Verbose "Found command file(s) in folder '$($c.FullName)'."
	                    $hasFolders = $true
	                } else {
	                    Write-Warning "Found empty folder '$($c.FullName)'."
	                }
	            } elseif ([IO.Path]::GetExtension($c.Name) -eq '.ps1') {
	                Write-Verbose "Found command file(s) in folder '$($root)\Commands'."
	                $hasFiles = $true
	            }
	        }
	
	        if ($hasFiles) {
	            if ($hasFolders) {
	                Write-Warning "Found a mix of command files and folders in '$($root)\Commands'."
	            }
	
	            Write-Verbose "Importing command files in '$($root)\Commands'..."
	
	            $module = "$(Split-Path $root -Leaf)" -replace '%20', ' '
	
	            $children | where { -not($_ -is [System.IO.DirectoryInfo]) -and [IO.Path]::GetExtension($_.Name) -eq '.ps1' } | foreach {
	                Write-Verbose "Found command file '$($_.Name)'."
	                Write-Output (Import-AcceleratorCommand -Path $_.FullName -DefaultModuleName $module)
	            }
	        }
	
	        if ($hasFolders) {
	            Write-Verbose "Importing command folders in '$($root)\Commands'..."
	            $children | where { $_ -is [System.IO.DirectoryInfo] } | foreach {
	                Write-Verbose "Scanning directory '$($_.FullName)'..."
	                Get-ChildItem $_.FullName -Filter '*.ps1' | foreach {
	                    Write-Verbose "Found command file '$($_.Name)'."
	                    Write-Output (Import-AcceleratorCommand -Path $_.FullName)
	            	}
	            }
	        }
	    } else {
	        Write-Warning "Path '$($root)' contains no commands."
	    }
	}
	
	return $menu
}

function Get-AcceleratorPath {
	[CmdletBinding()]
	param(
	    [switch]$AsArray
	)
	
	$acceleratorPath = $env:AcceleratorPath
	
	if (-not($acceleratorPath)) {
	    Write-Verbose "Using default commands path."
	    $acceleratorPath = $PSScriptRoot
	}
	
	Write-Verbose "AcceleratorPath=$($acceleratorPath)"
	
	if ($AsArray.IsPresent) {
	    return [array]($acceleratorPath -split ';')
	} else {
	    return $acceleratorPath
	}
}

function Import-AcceleratorCommand {
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
	
	    return $command
	}
}

Export-ModuleMember -Function 'Read-Confirmation'
Export-ModuleMember -Function 'Start-Accelerator'
