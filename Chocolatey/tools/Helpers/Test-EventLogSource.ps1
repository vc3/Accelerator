function Test-EventLogSource {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name
    )

    # https://stackoverflow.com/questions/28196488/how-to-check-if-event-log-with-certain-source-name-exists
    [System.Diagnostics.EventLog]::SourceExists($Name)
}
