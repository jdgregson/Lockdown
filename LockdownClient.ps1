Param (
    [switch]$alert,
    [string]$message,
    [string]$title = "Lockdown Alert",
    [switch]$service,
    [switch]$install
)
$BLUE_ICON_FILE = "C:\lockdown\var\lock-blue.ico"
$RED_ICON_FILE = "C:\lockdown\var\lock-red.ico"
$ICON = $Null

function Get-LockdownPulse {
    return (Lockdown -Pulse)
}


function Get-LastWakeTime {
    $evt = (Get-EventLog -LogName System -InstanceID 1 -Source "Microsoft-Windows-Power-Troubleshooter" -Newest 1)
    return Date((($evt.Message -split "Wake Time: ")[1] -split "`n")[0])
}


function Install-LockdownClientTask {
    Param (
        [string]$TaskName = "LockdownClient"
    )

    $task = (Get-ScheduledTask $TaskName -ErrorAction SilentlyContinue)
    if ($task) {
        $prompt = Read-Host "A scheduled task named `"$TaskName`" already exists. Would you like to replace it? (y/N)"
        if ($prompt -ne "y") {
            return
        }
        Write-Host "Stopping existing task..."
        $task | Stop-ScheduledTask
        Write-Host "Deleting existing task..."
        $task | Unregister-ScheduledTask -Confirm:$False
    }
    Write-Host "Installing new scheduled task `"$TaskName`"..."
    $action = New-ScheduledTaskAction -Execute 'Powershell.exe' `
        -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSScriptRoot\Start-LockdownClient.ps1`""
    $settings = New-ScheduledTaskSettingsSet
    $settings.DisallowStartIfOnBatteries = $False
    $settings.StopIfGoingOnBatteries = $False
    $settings.Hidden = $True
    $settings.ExecutionTimeLimit = "PT0S"
    $settings.StartWhenAvailable = $True
    $settings.AllowHardTerminate = $False
    $trigger =  New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 5)
    $task = Register-ScheduledTask -Action $action -Trigger $trigger -TaskName $TaskName -Settings $settings

    $task = (Get-ScheduledTask $TaskName -ErrorAction SilentlyContinue)
    if ($task) {
        Write-Host "The task installed successfully."
        $prompt = Read-Host "Would you like to start the task now? (Y/n)"
        if ($prompt -ne "n") {
            $task | Start-ScheduledTask
        }
    } else {
        Write-Warning "Cound not determine if the task installed successfully."
    }
}


function Show-LockdownClientIcon {
    [void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
    $pulse = $(Get-LockdownPulse)
    $script:ICON = New-Object System.Windows.Forms.NotifyIcon
    $script:ICON.Icon = $BLUE_ICON_FILE
    $script:ICON.Text = "LockdownClient is running`nHeartbeat: $pulse`nUpdated: $((Date).ToString('HH:mm:ss'))"
    Register-ObjectEvent $script:ICON "MouseClick" -Action {Start PowerShell LockdownUI}
    $script:ICON.Visible = $True
}


function Hide-LockdownClientIcon {
    $script:ICON.Dispose()
}


function Update-LockdownClientIcon {
    Param (
        [string]$text = "LockdownClient is running`nHeartbeat: $(Get-LockdownPulse)`nUpdated: $((Date).ToString('HH:mm:ss'))",
        [string]$icon = $BLUE_ICON_FILE
    )

    $pulse = $(Get-LockdownPulse)
    if ($pulse -eq "Alive") {
        $icon = $BLUE_ICON_FILE
    } else {
        $icon = $RED_ICON_FILE
    }

    $script:ICON.Icon = $icon
    $script:ICON.Text = $text
}


function Show-Message {
    Param (
        [string]$title,
        [string]$message
    )

    $FallbackNotification = @"
        Import-Module psui1 -Force -DisableNameChecking
        Set-UIConsoleTitle "'$title'"
        Set-UIConsoleIcon "'$RED_ICON_FILE'"
        Set-UIConsoleWidth 100
        Set-UIConsoleHeight 18
        Set-UIBufferSize 100 18
        Write-UIPaintedScreen "DarkRed"
        Set-UIConsoleColor "DarkRed "White"
        Write-Host "'`n`n  $message`n'"

        `$oldY = (Get-UICursorPositionY)
        Set-UIFocusedWindow -WindowTitle "'$title'"
        Set-UICursorPosition 0 ((Get-UIConsoleHeight) - 1)
        Write-Host ("' '" * (Get-UIConsoleWidth))
        Set-UICursorPosition -X 1 -Y `$oldY
        Wait-AnyKey
"@
    if ($message -match "#") {
        $title = $message.split("#")[0]
        $message = $message.split("#")[1]
    }
    if (Get-Command "New-BurntToastNotification" -ErrorAction SilentlyContinue) {
        New-BurntToastNotification -AppLogo $RED_ICON_FILE -Text $title,$message
    } else {
        Start Powershell $FallbackNotification
    }
}


if ($alert -and $message) {
    Show-Message $title $message
} elseif ($install) {
    Install-LockdownClientTask
} elseif ($service) {
    Show-LockdownClientIcon
    $AlertedOnDeadPulse = $False
    $config = (Get-LockdownPolicy)
    while ($True) {
        sleep 5
        Update-LockdownClientIcon

        if (Test-Path $config.AlertFilePath) {
            $alertmsg = (Get-Content $config.AlertFilePath)
            if ($alertmsg) {
                LockdownClient -Alert -Message $alertmsg
                Write-Host "" > $config.AlertFilePath
            }
        }

        $pulse = (Get-LockdownPulse)
        if ($pulse -eq "Dead" -and -not $AlertedOnDeadPulse) {
            if (-not((Get-LastWakeTime) -lt (Date).AddSeconds(-10)) -or
                    (Get-Item $config.StatusFilePath).LastWriteTime -gt (Date).AddSeconds(-30)) {
                continue
            }
            LockdownClient -Alert -Title "Lockdown not running" -Message "Lockdown does not appear to be running as no pulse has been recorded for more than thrity seconds."
            $AlertedOnDeadPulse = $True
        } elseif ($pulse -eq "Alive") {
            $AlertedOnDeadPulse = $False
        }
    }
} else {
    Get-Help LockdownClient
}
