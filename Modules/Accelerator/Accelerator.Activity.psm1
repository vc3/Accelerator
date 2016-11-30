
$script:activityStack = New-Object 'System.Collections.Generic.List[string]'

$script:activityProcessedCount = @{}

$script:activityTotalSize = @{}

$script:activityCurrentOperation = @{}

function Get-Activity {
    [CmdletBinding()]
    param(
        [Alias('Activity')]
        [Parameter()]
        [string]$Name
    )

    if ($Name) {
        return $Name
    } else {
        if ($script:activityStack.Count -gt 0) {
            return $script:activityStack[$script:activityStack.Count - 1]
        } else {
            Write-Error "No activities are currently active."
            return
        }
    }
}

function Start-Activity {
    [CmdletBinding()]
    param(
        [Alias('Activity')]
        [Parameter(Mandatory=$true)]
        [string]$Name,

        [int]$TotalSize,

        [switch]$UseHost
    )

    $activityStack.Add($Name)

    $script:activityProcessedCount[$Name] = 0
    $script:activityTotalSize[$Name] = $TotalSize
    $script:activityCurrentOperation[$Name] = ''

    if ($AcceleratorInteractive) {
        Write-Progress -Activity $Name -PercentComplete 0
    }

    if ($UseHost) {
        Write-Host "Starting activity '$($Name)'..."
    }
}

function Update-ActivityStatus {
    [CmdletBinding(DefaultParameterSetName='CurrentItem')]
    param(
        [Alias('Activity')]
        [Parameter()]
        [string]$Name,

        [Parameter(Mandatory=$true, ParameterSetName='CurrentItem')]
        [string]$Item,

        [Parameter(ParameterSetName='CurrentProgress')]
        [switch]$Increment,

        [Alias('Factor')]
        [Parameter(ParameterSetName='CurrentProgress')]
        [int]$IncrementFactor = 1,

        [switch]$UseHost
    )

    $name = Get-Activity $Name

    $previousItem = $null
    $currentItem = $script:activityCurrentOperation[$name]
    $processedItems = $script:activityProcessedCount[$name]
    $totalItems = $script:activityTotalSize[$name]

    if ($PSCmdlet.ParameterSetName -eq 'CurrentItem') {
        $currentItem = $Item
        $previousItem = $script:activityCurrentOperation[$name]
        $script:activityCurrentOperation[$name] = $Item
    } elseif ($PSCmdlet.ParameterSetName -eq 'CurrentProgress') {
        $script:activityCurrentOperation[$name] = $null
        $currentItem = $null
        $processedItems += $IncrementFactor
        $script:activityProcessedCount[$name] = $processedItems
    }

    if ($AcceleratorInteractive) {
        Write-Progress -Activity $name -Status 'Progress:' -CurrentOperation $currentItem -PercentComplete (($processedItems / $totalItems) * 100)
    }

    if ($UseHost) {
        if ($Item) {
            Write-Host "Start processing item '$($currentItem)'..."
        } else {
            Write-Host "Completed processing item '$($previousItem)'."
        }
    }
}

function Stop-Activity {
    param(
        [Alias('Activity')]
        [Parameter()]
        [string]$Name,

        [switch]$UseHost
    )

    $name = Get-Activity $Name

    if ($AcceleratorInteractive) {
        Write-Progress -Activity $name -PercentComplete 100 -Completed
    }

    if ($UseHost) {
        Write-Host "Completed activity '$($name)'."
    }
}

Export-ModuleMember -Function 'Start-Activity'
Export-ModuleMember -Function 'Update-ActivityStatus'
Export-ModuleMember -Function 'Stop-Activity'
