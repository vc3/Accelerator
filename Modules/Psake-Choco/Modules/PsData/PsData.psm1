# v1.0 http://huddledmasses.org/configuration-files-for-powershell-part-1/
# v2.0 wrap as Import/Convert
# v2.1 Add a few helper functions so we can have type-safe GUIDs, DateTime, and even PSCustomObject
#      The custom object isn't really necessary, since it's roughly equivalent to a hashtable (script not supported)
# v3.0 Add 'ConvertTo-PSData' from blog post, as well as 'Export-PSData'. Additional cleanup and normalization.

<#
.SYNOPSIS
Imports a PowerShell Data Language file (i.e. *.psd1) and creates corresponding objects within Windows PowerShell.
#>
function Import-PSData {
	[CmdletBinding(PositionalBinding=$false)]
	param(
		# Specifies the PowerShell data file(s) to import.
		[Parameter(Mandatory=$false, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Position=0)]
		[string]$Path,

		# Specifies the PowerShell data file(s). Unlike Path, the value of the LiteralPath parameter is used exactly as it is typed. No characters are interpreted as wildcards. If the path includes escape characters, enclose it in single quotation marks. Single quotation marks tell Windows PowerShell not to interpret any characters as escape sequences.
		[Parameter(Mandatory=$false)]
		[string]$LiteralPath,

		#  The commands that are allowed in the data language. By default, the following are allowed: "PSObject", "GUID", "DateTime", "DateTimeOffset", "ConvertFrom-StringData", and "Join-Path".
		[Parameter(Mandatory=$false)]
		[string[]]$AllowedCommands  = ("PSObject", "GUID", "DateTime", "DateTimeOffset", "ConvertFrom-StringData", "Join-Path"),

		# Additional variables that are allowed in the data language. These constants are always allowed: "PSScriptRoot", "PSCulture", "PSUICulture", "True", "False", and "Null".
		[Alias('AllowedVariables')]
		[Parameter(Mandatory=$false)]
		[string[]]$AdditionalAllowedVariables = @(),

		# The PSScriptRoot value (defaults to the PSParentPath of the input file).
		[Alias("PSParentPath")]
		[Alias("PSScriptRoot")]
		[Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$true)]
		[string]$ScriptRoot = $(if ($Path) { Split-Path $Path })
	)

	process {
		if ($LiteralPath) {
			$content = Get-Content -LiteralPath $LiteralPath -Raw
		}
		else {
			$content = Get-Content -Path $Path -Raw
		}
		if (-not $content) {
			return
		}

		$PSBoundParameters.Remove("Path") | Out-Null
		$PSBoundParameters.Remove("LiteralPath") | Out-Null
		if (!$PSBoundParameters.ContainsKey("ScriptRoot")) {
			$PSBoundParameters["ScriptRoot"] = $ScriptRoot
		}

		ConvertFrom-PSData $content @PSBoundParameters
	}
}

<#
.SYNOPSIS
Convert PowerShell Data Language data to PowerShell objects.
#>
function ConvertFrom-PSData {
	[CmdletBinding()]
	param(
		#  The PowerShell data to convert.
		[Parameter(Mandatory=$true, ValueFromPipeline=$true, Position=0)]
		[string]$InputObject,

		# The commands that are allowed in the data language. By default, to following are allowed: "PSObject", "Hashtable", "GUID", "DateTime", "DateTimeOffset", "ConvertFrom-StringData", and "Join-Path".
		[Parameter(Mandatory=$false)]
		[string[]]$AllowedCommands = ("PSObject", "Hashtable", "GUID", "DateTime", "DateTimeOffset", "ConvertFrom-StringData", "Join-Path"),

		# Additional variables that are allowed in the data language. These constants are always allowed: "PSScriptRoot", "PSCulture", "PSUICulture", "True", "False", and "Null".
		[Alias('AllowedVariables')]
		[Parameter(Mandatory=$false)]
		[string[]]$AdditionalAllowedVariables = @(),

		# The PSScriptRoot value (defaults to the current working directory).
		[Alias("PSParentPath")]
		[Alias("PSScriptRoot")]
		[Parameter(ValueFromPipelineByPropertyName=$True)]
		[string]$ScriptRoot = $PWD.Path
	)
	begin {
		$AdditionalAllowedVariables += "PSScriptRoot", "ScriptRoot","PSCulture","PSUICulture","True","False","Null"
		$PSData = ""
	}
	process {
		$PSData += $InputObject
	}
	end {
		$ErrorActionPreference = "Stop"

		$ScriptRoot = Convert-Path $ScriptRoot

		Write-Verbose "Converting PSData '$($PSData)'..."

		# We can't have a signature block in DataLanguage, but PowerShell will sign psd1 files (WAT?!)
		$PSData = $PSData -replace "# SIG # Begin signature block(?s:.*)"

		# STEP ONE: Parse the file
		$Tokens = $Null; $ParseErrors = $Null
		$AST = [System.Management.Automation.Language.Parser]::ParseInput($PSData, [ref]$Tokens, [ref]$ParseErrors)

		if ($ParseErrors -ne $null) {
			$PSCmdlet.ThrowTerminatingError( (New-Object System.Management.Automation.ErrorRecord "Parse error reading $Path", "Parse Error", "InvalidData", $ParseErrors) )
		}

		# There's no way to set PSScriptRoot, so I can't make it return the right value
		if ($roots = @($Tokens | Where-Object { ("Variable" -eq $_.Kind) -and ($_.Name -eq "PSScriptRoot") } | ForEach-Object { $_.Extent } )) {
			for ($r = $roots.count - 1; $r -ge 0; $r--) {
				# Make $PSScriptRoot with $ScriptRoot instead.
				$PSData = $PSData.Remove($roots[$r].StartOffset+1, 2)
			}
			$AST = [System.Management.Automation.Language.Parser]::ParseInput($PSData, [ref]$Tokens, [ref]$ParseErrors)
		}

		$Script = $AST.GetScriptBlock()

		#Write-Host $Script.ToString()
		#$Script.GetPowerShell() | Get-Member | foreach { Write-Host "$($_.Name) ($($_.MemberType))" }

		# STEP TWO: CheckRestrictedLanguage, if it fails, die.
		$Script.CheckRestrictedLanguage($AllowedCommands, $AdditionalAllowedVariables, $true)

		# STEP THREE: Invoke, but take credit for the errors
		try { $Script.InvokeReturnAsIs(@()) } catch { $PSCmdlet.ThrowTerminatingError($_) }
	}
}

<#
.SYNOPSIS
Export to PowerShell Data Language files (.psd1).
#>
function Export-PSData {
	[CmdletBinding(PositionalBinding=$false)]
	param(
		# Specifies the object to be written to the file. Enter a variable that contains the objects, or type a command or expression that gets the objects. You can also pipe objects to Export-Clixml.
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)]
		[PSObject]$InputObject,

		# Specifies the path to the output file.
		[Parameter(Mandatory=$false, ValueFromPipelineByPropertyName=$false, Position=0)]
		[String]$Path,

		# Specifies the path to the file where the PowerShell data representation of the object will be stored. Unlike Path, the value of the LiteralPath parameter is used exactly as it is typed. No characters are interpreted as wildcards. If the path includes escape characters, enclose it in single quotation marks. Single quotation marks tell Windows PowerShell not to interpret any characters as escape sequences.
		[Parameter(Mandatory=$false)]
		[String]$LiteralPath,

		# Specifies the type of encoding for the target file. Valid values are ASCII, UTF8, UTF7, UTF32, Unicode, BigEndianUnicode, Default, and OEM. Unicode is the default.
		[ValidateSet('ASCII', 'UTF8', 'UTF7', 'UTF32', 'Unicode', 'BigEndianUnicode', 'Default', 'OEM')]
		[Parameter()]
		[string]$Encoding='Unicode',

		# Allows the cmdlet to overwrite an existing read-only file. Even using the Force parameter, the cmdlet cannot override security restrictions.
		[Parameter()]
		[switch]$Force,

		# Will not overwrite (replace the contents) of an existing file. By default, if a file exists in the specified path, Export-PSData overwrites the file without warning.
		[Parameter()]
		[switch]$NoClobber,

		# The text to use for indentation.
		[Parameter(Mandatory=$false)]
		[string]$Indent = '  '
	)

	# NOTE: Modeled after 'Export-Csv' and 'Export-CliXml' from 'Microsoft.PowerShell.Utility'.

	$dataText = ConvertTo-PSData -InputObject $InputObject -Indent $Indent

	if ($LiteralPath) {
		Out-File -InputObject $dataText -LiteralPath $LiteralPath -Encoding $Encoding -Force:$Force -NoClobber:$NoClobber
	}
	else {
		Out-File -InputObject $dataText -FilePath $Path -Encoding $Encoding -Force:$Force -NoClobber:$NoClobber
	}
}

<#
.SYNOPSIS
Converts a PSObject to PowerShell data language text.
#>
function ConvertTo-PSData {
	[CmdletBinding(PositionalBinding=$false)]
	param(
		# The PSObject to convert.
		[Parameter(Mandatory=$true, ValueFromPipeline=$true, Position=0)]
		[object]$InputObject,

		# The text to use for indentation.
		[Parameter(Mandatory=$false)]
		[string]$Indent = '  '
	)
	process {
		if ($InputObject -is [Int16] -or
			$InputObject -is [Int32] -or
			$InputObject -is [Byte]) {
			"{0:G}" -f $InputObject
		}
		elseif ($InputObject -is [Double])  {
			"{0:G}" -f $InputObject -replace '^(\d+)$','.0'
		}
		elseif ($InputObject -is [Int64])  {
			"{0:G}l" -f $InputObject
		}
		elseif ($InputObject -is [Decimal])  {
			"{0:G}d" -f $InputObject
		}
		elseif ($InputObject -is [bool])  {
			if ($InputObject) { '$True' } else { '$False' }
		}
		elseif ($InputObject -is [String]) {
			"'{0}'" -f $InputObject
		}
		elseif ($InputObject -is [System.Collections.IDictionary]) {
			"@{{`n$Indent{0}`n}}" -f ($(
			foreach ($key in @($InputObject.Keys)) {
				if ("$key" -match '^(\w+|-?\d+\.?\d*)$') {
					"$key = " + (ConvertTo-PSData $InputObject.($key) -Indent $Indent)
				}
				else {
					"'$key' = " + (ConvertTo-PSData $InputObject.($key) -Indent $Indent)
				}
			}) -split "`n" -join "`n$Indent")
		}
		elseif ($InputObject -is [System.Collections.IEnumerable]) {
			"@($($(foreach ($item in @($InputObject)) { ConvertTo-PSData $item -Indent $Indent }) -join ','))"
		}
		elseif ($InputObject -is [DateTime]) {
			"DateTime('{0}')" -f ($InputObject.ToString('O'))
		}
		elseif ($InputObject -is [PSObject]) {
			$hashtable = @{}
			$InputObject.PSObject.Properties | foreach { $hashtable."$($_.Name)" = $_.Value }
			ConvertTo-PSData -InputObject $hashtable -Indent $Indent
		}
		else
		{
			"'{0}'" -f $InputObject
		}
	}
}

# These functions are helpers to let us use dissallowed types in data sections
# (see about_data_sections) and .psd1 files (see ConvertFrom-DataString)
function PSObject {
	<#
		.Synopsis
			Creates a new PSCustomObject with the specified properties
		.Description
			This is just a wrapper for the PSObject constructor with -Property $Value
			It exists purely for the sake of psd1 serialization
		.Parameter Value
			The hashtable of properties to add to the created objects
	#>
	param([hashtable]$Value)
	New-Object System.Management.Automation.PSObject -Property $Value
}

function Guid {
	<#
		.Synopsis
			Creates a GUID with the specified value
		.Description
			This is basically just a type cast to GUID.
			It exists purely for the sake of psd1 serialization
		.Parameter Value
			The GUID value.
	#>
	param([string]$Value)
	[Guid]$Value
}

function DateTime {
	<#
		.Synopsis
			Creates a DateTime with the specified value
		.Description
			This is basically just a type cast to DateTime, the string needs to be castable.
			It exists purely for the sake of psd1 serialization
		.Parameter Value
			The DateTime value, preferably from .Format('o'), the .Net round-trip format
	#>
	param([string]$Value)
	[DateTime]$Value
}

function DateTimeOffset {
	<#
		.Synopsis
			Creates a DateTimeOffset with the specified value
		.Description
			This is basically just a type cast to DateTimeOffset, the string needs to be castable.
			It exists purely for the sake of psd1 serialization
		.Parameter Value
			The DateTimeOffset value, preferably from .Format('o'), the .Net round-trip format
	#>
	param([string]$Value)
	[DateTimeOffset]$Value
}

export-modulemember Import-PSData
export-modulemember ConvertFrom-PSData
export-modulemember Export-PSData
export-modulemember ConvertTo-PSData
