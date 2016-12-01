################################################################################
#  Accelerator-StringUtils                                                     #
#  --------------------------------------------------------------------------  #
#  Author(s): Bryan Matthews                                                   #
#  Company: VC3, Inc.                                                          #
################################################################################

$regex = "(\{([A-Za-z_][A-Za-z0-9_]*)\})"

function Splice-String {
    param(
        [string]$Text,

        [int]$RemoveAt,

        [int]$RemoveCount,

        [string]$InsertText
    )

    Write-Verbose "Splicing $($RemoveCount) characters at index $($RemoveAt) from string '$($Text)' and inserting '$($InsertText)'."

    $pre = $Text.Substring(0, $RemoveAt)
    if ($RemoveAt + $RemoveCount -ge $Text.Length) {
        $post = ''
    } else {
        $post = $Text.Substring($RemoveAt + $RemoveCount)
    }
    return $pre + $InsertText + $post
}

function ConvertFrom-TemplateString {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Template,

        [Hashtable]$ReplacementValues,

        [switch]$UsePowerShellVariables,

        [switch]$UseEnvironmentVariables
    )

    $str = $Template

    Write-Verbose "Converting from template string '$($Template)'..."
    Write-Verbose "ReplacementValues=$($ReplacementValues.Keys -join ', ')"

    $match = [Regex]::Match($str, $regex)
    while ($match.Success) {
        Write-Verbose "Found match at $($match.Index) of length $($match.Length)."

        $matchValue = "$($match.Groups[2])"
        $matchReplacement = $null
        $matchReplacementFound = $false

        if (-not($matchReplacementFound)) {
            if ($ReplacementValues -and $ReplacementValues.ContainsKey($matchValue)) {
                Write-Verbose "Replacement values contains key '$($matchValue)'."
                $matchReplacement = $ReplacementValues[$matchValue]
                $matchReplacementFound = $true
            } else {
                Write-Verbose "Replacement values does not contain key '$($matchValue)'."
            }
        }

        if (-not($matchReplacementFound)) {
            if ($UsePowerShellVariables) {
                $psVar = Get-Variable $matchValue -ErrorAction SilentlyContinue
                if ($psVar) {
                    Write-Verbose "PowerShell variable '$($matchValue)' was found."
                    $matchReplacement = $psVar.Value
                    $matchReplacementFound = $true
                } else {
                    Write-Verbose "PowerShell variable '$($matchValue)' does not exist."
                }
            }
        }

        if (-not($matchReplacementFound)) {
            if ($UseEnvironmentVariables) {
                $envVar = Get-Item "env:$($matchValue)" -ErrorAction SilentlyContinue
                if ($envVar) {
                    Write-Verbose "Environment variable '$($matchValue)' was found."
                    $matchReplacement = $envVar.Value
                    $matchReplacementFound = $true
                } else {
                    Write-Verbose "Environment variable '$($matchValue)' does not exist."
                }
            }
        }

        if (-not($matchReplacement)) {
            Write-Error "Couldn't find replacement for token '$($matchValue)'."
        }

        $str = Splice-String $str $match.Index $match.Length $matchReplacement

        $match = [Regex]::Match($str, $regex)
    }

    return $str
}

Export-ModuleMember -Function 'ConvertFrom-TemplateString'
