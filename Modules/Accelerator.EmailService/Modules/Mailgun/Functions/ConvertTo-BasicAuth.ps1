function ConvertTo-BasicAuth {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [string]$Username,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [SecureString]$Password
    )

    # https://gist.github.com/ctigeek/d79484ccbaec7e71a837
    $idpass = "$($Username):$($Password | Convert-SecureStringToPlainText)"
    $basicauth = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($idpass))

    return $basicauth
}
