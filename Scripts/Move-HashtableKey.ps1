[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [Hashtable]$Source,

    [Parameter(Mandatory=$true)]
    [string[]]$SourceKeys,

    [Parameter(Mandatory=$true)]
    [Hashtable]$Target,

    [Parameter(Mandatory=$true)]
    [string]$TargetKey,

    [object]$DefaultValue
)

for ($i = 0; $i -lt $SourceKeys.Count; $i += 1) {
    $key = $SourceKeys[$i]
    Write-Verbose "Checking key '$($key)'..."
    if ($Source.ContainsKey($key)) {
        $item = $Source | where { $_.Name -eq $key }
        Write-Verbose "Moving source value from '$($key)' to key '$($TargetKey)'..."
        $Target[$TargetKey] = $Source[$key]
        $Source.Remove($key) | Out-Null
        return $item
    }
}

if ($PSBoundParameters.ContainsKey('DefaultValue')) {
    Write-Verbose "Using default value for key '$($TargetKey)'..."
    $Target[$TargetKey] = $DefaultValue
}
