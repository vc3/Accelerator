function Test-EventLog {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [string] $Name
    )

    try {
        Get-EventLog -LogName $Name -Newest 1 -EA 'Stop' | Out-Null
        return $true
    } catch {
        return $false
    }
}
