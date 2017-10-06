function Convert-SecureStringToPlainText {
    <#
        .SYNOPSIS
        Converts the given SecureString to plain text.
    #>
    [CmdletBinding()]
    param(
        # The secure string to convert to plain text
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [System.Security.SecureString]$SecureString
    )

	process {
	    # http://stackoverflow.com/a/28353003/170990
	    # The 'NetworkCredential' trick doesn't seem to work in PowerShell 2 (???).
		[System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString))
	}
}
