[CmdletBinding()]
param(
    [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
    [Hashtable]$InputObject,

    [Parameter(Mandatory=$true)]
    [string[]]$Keys,

    [object]$DefaultValue
)

for ($i = 0; $i -lt $Keys.Count; $i += 1) {
    $key = $Keys[$i]
    Write-Verbose "Checking key '$($key)'..."
    if ($InputObject.ContainsKey($key)) {
        Write-Verbose "Extracting value from key '$($key)'..."
        $value = $InputObject[$key]
        $InputObject.Remove($key) | Out-Null
        return $value
    }
}

if ($PSBoundParameters.ContainsKey('DefaultValue')) {
    Write-Verbose "Returning default value..."
    return $DefaultValue
}
