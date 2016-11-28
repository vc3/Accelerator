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
