################################################################################
#  Accelerator-Credentials                                                     #
#  --------------------------------------------------------------------------  #
#  Author(s): Bryan Matthews                                                   #
#  Company: VC3, Inc.                                                          #
################################################################################

if (-not($PSScriptRoot)) {
    $PSScriptRoot = Split-Path $script:MyInvocation.MyCommand.Path
}

$supportsCredentialManager = $false

if ($PSVersionTable.PSVersion -ge '3.0') {
    Import-Module "$($PSScriptRoot)\..\CredentialManager\CredentialManager.psd1"
    $supportsCredentialManager = $true
}

$getStoredCredential = $ExecutionContext.InvokeCommand.GetCommand('Get-StoredCredential', 'Cmdlet')
$newStoredCredential = $ExecutionContext.InvokeCommand.GetCommand('New-StoredCredential', 'Cmdlet')
$removeStoredCredential = $ExecutionContext.InvokeCommand.GetCommand('Remove-StoredCredential', 'Cmdlet')

function Get-SavedCredential {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Target,

        [Parameter()]
        [string]$Username
    )

    $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($identity)
    $isAdmin = $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)

    if ($isAdmin) {
        $credFolder = "$($env:ALLUSERSPROFILE)\Credentials\$($identity.User)"
    } else {
        $credFolder = "$($env:LOCALAPPDATA)\Credentials"
    }

    if ($Username) {
        $fileFilter = "$($Username)~@~$($Target).txt"
    } else {
        $fileFilter = "*~@~$($Target).txt"
    }

    Write-Verbose "Looking for file '$($fileFilter)' in folder '$($credFolder)'..."

    $matchingFiles = Get-ChildItem $credFolder -Filter $fileFilter | select -ExpandProperty 'FullName'

    foreach ($credFile in $matchingFiles) {
        Write-Verbose "Reading file '$($credFile)'..."
        $credFileName = Split-Path $credFile -Leaf
        $username = $credFileName.Substring(0, $credFileName.Length - "~@~$($Target).txt".Length)
        $passwordSecure = Get-Content $credFile | ConvertTo-SecureString
		$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, $passwordSecure
        return $cred
    }
}

function New-SavedCredential {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Target,

        [Parameter(Mandatory=$true)]
        [string]$Username,

        [Parameter(Mandatory=$true)]
        [string]$Password
    )

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

    $credFile = "$($credFolder)\$($Username)~@~$($Target).txt"

    $passwordSecure = $password | ConvertTo-SecureString -Force -AsPlainText

    $passwordSecure | ConvertFrom-SecureString | Out-File $credFile -Force
}

function Get-StoredCredential {
    throw "Command 'Get-StoredCredential' is not implemented."
}

function New-StoredCredential {
    throw "Command 'New-StoredCredential' is not implemented."
}

function Remove-StoredCredential {
    throw "Command 'Remove-StoredCredential' is not implemented."
}

Export-ModuleMember -Function 'Get-StoredCredential'
Export-ModuleMember -Function 'New-StoredCredential'
Export-ModuleMember -Function 'Remove-StoredCredential'
