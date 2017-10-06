function Get-SavedCredential {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Target,

        [string]$Username,

        [string]$Path
    )

    if ($Path) {
        if (-not(Test-Path $Path)) {
            Write-Error "Path '$($Path)' doesn't exist."
            return
        }
    } else {
        $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
        $isAdmin = $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)

        if ($isAdmin) {
            $Path = "$($env:ALLUSERSPROFILE)\Credentials\$($identity.User)"
        } else {
            $Path = "$($env:LOCALAPPDATA)\Credentials"
        }
    }

    if ($Username) {
        $fileFilter = "$($Username)~@~$($Target).txt"
    } else {
        $fileFilter = "*~@~$($Target).txt"
    }

    Write-Verbose "Looking for file '$($fileFilter)' in folder '$($Path)'..."

    $matchingFiles = Get-ChildItem $Path -Filter $fileFilter | select -ExpandProperty 'FullName'

    foreach ($credFile in $matchingFiles) {
        Write-Verbose "Reading file '$($credFile)'..."
        $credFileName = Split-Path $credFile -Leaf
        $username = $credFileName.Substring(0, $credFileName.Length - "~@~$($Target).txt".Length)
        $passwordSecure = Get-Content $credFile | ConvertTo-SecureString
		$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $passwordSecure
        return $cred
    }
}
