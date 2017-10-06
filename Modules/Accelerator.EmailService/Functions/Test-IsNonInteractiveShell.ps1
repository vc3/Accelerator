function Test-IsNonInteractiveShell {
    [CmdletBinding()]
    param(
    )

    # https://github.com/UNT-CAS-ITS/Test-IsNonInteractiveShell
    # https://stackoverflow.com/questions/9738535/powershell-test-for-noninteractive-mode/34098997#34098997
    if ([Environment]::UserInteractive) {
        foreach ($arg in [Environment]::GetCommandLineArgs()) {
            # Test each Arg for match of abbreviated '-NonInteractive' command.
            if ($arg -like '-NonI*') {
                Write-Verbose "Process was started with the -NonInteractive flag."
                return $true
            }
        }

        Write-Verbose "The shell appears to be interactive."
        return $false
    } else {
        Write-Verbose "User session is not interactive."
        return $false
    }
}
