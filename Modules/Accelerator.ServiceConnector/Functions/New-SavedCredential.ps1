function New-SavedCredential {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Target,

        [Parameter(Mandatory=$true)]
        [string]$Username,

        [Parameter(Mandatory=$true)]
        [SecureString]$Password,

        [string]$Path
    )

    if ($Path) {
        if (-not(Test-Path $Path)) {
            Write-Error "Path '$($Path)' doesn't exist."
            return
        }
    } else {
        $identity  = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
        $isAdmin = $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)

        if ($isAdmin) {
            $credFolder = "$($env:ALLUSERSPROFILE)\Credentials\$($identity.User)"
        } else {
            $credFolder = "$($env:LOCALAPPDATA)\Credentials"
        }

        if (-not(Test-Path $credFolder)) {
            mkdir $credFolder | Out-Null
        }
    }

    $credFile = "$($credFolder)\$($Username)~@~$($Target).txt"

    $Password | ConvertFrom-SecureString | Out-File $credFile -Force
}
