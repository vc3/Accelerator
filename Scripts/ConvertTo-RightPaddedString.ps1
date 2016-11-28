[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$Text,

    [Parameter(Mandatory=$true)]
    [int]$Width
)

if ($Text.Length -gt $Width) {
    $padLength = $Width - $Text.Length
    return (' ' * $padLength) + $Text
} else {
    return $Text
}
