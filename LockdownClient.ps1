# File: LockdownClient.ps1
# Project: Lockdown, https://github.com/jdgregson/Lockdown
# Copyright (C) Jonathan Gregson, 2020
# Author: Jonathan Gregson <jonathan@jdgregson.com>

Param (
    [Switch]$Alert,

    [String]$Message,

    [String]$Title = "Lockdown Alert",

    [Switch]$Service,

    [Switch]$Install
)


$blueFileIcon = "C:\lockdown\var\lock-blue.ico"
$redFileIcon = "C:\lockdown\var\lock-red.ico"
$icon = $null


function Get-LockdownPulse {
    return (Lockdown -Pulse)
}


function Get-LastWakeTime {
    $evt = (Get-EventLog -LogName System -InstanceID 1 -Source "Microsoft-Windows-Power-Troubleshooter" -Newest 1)
    Date((($evt.Message -split "Wake Time: ")[1] -split "`n")[0])
}


function Install-LockdownClientTask {
    Param (
        [String]$TaskName = "LockdownClient"
    )

    $task = Get-ScheduledTask $TaskName -ErrorAction SilentlyContinue
    if ($task) {
        $prompt = Read-Host "A scheduled task named `"$TaskName`" already exists. Would you like to replace it? (y/N)"
        if ($prompt -ne "y") {
            return
        }
        Write-Host "Stopping existing task..."
        $task | Stop-ScheduledTask
        Write-Host "Deleting existing task..."
        $task | Unregister-ScheduledTask -Confirm:$false
    }
    Write-Host "Installing new scheduled task `"$TaskName`"..."
    $action = New-ScheduledTaskAction -Execute "Powershell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSScriptRoot\Start-LockdownClient.ps1`""
    $settings = New-ScheduledTaskSettingsSet
    $settings.DisallowStartIfOnBatteries = $false
    $settings.StopIfGoingOnBatteries = $false
    $settings.Hidden = $true
    $settings.ExecutionTimeLimit = "PT0S"
    $settings.StartWhenAvailable = $true
    $settings.AllowHardTerminate = $false
    $trigger = New-ScheduledTaskTrigger -Once -At Get-Date -RepetitionInterval (New-TimeSpan -Minutes 5)
    $task = Register-ScheduledTask -Action $action -Trigger $trigger -TaskName $TaskName -Settings $settings

    $task = Get-ScheduledTask $TaskName -ErrorAction SilentlyContinue
    if ($task) {
        Write-Host "The task installed successfully."
        $prompt = Read-Host "Would you like to start the task now? (Y/n)"
        if ($prompt -ne "n") {
            $task | Start-ScheduledTask
        }
    } else {
        Write-Warning "Could not determine if the task installed successfully."
    }
}


function Show-LockdownClientIcon {
    [void][System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
    $pulse = Get-LockdownPulse
    $script:icon = New-Object System.Windows.Forms.NotifyIcon
    $script:icon.Icon = $blueFileIcon
    $script:icon.Text = "Lockdown is running`nHeartbeat: $pulse`nUpdated: $((Date).ToString('HH:mm:ss'))"
    Register-ObjectEvent $script:ICON "MouseClick" -Action {Start PowerShell LockdownUI}
    $script:icon.Visible = $true
}


function Hide-LockdownClientIcon {
    $icon.Dispose()
}


function Update-LockdownClientIcon {
    Param (
        [String]$Text = "LockdownClient is running`nHeartbeat: $(Get-LockdownPulse)`nUpdated: $((Date).ToString('HH:mm:ss'))",
        [String]$Icon = $blueFileIcon
    )

    $pulse = Get-LockdownPulse
    if ($pulse -eq "Alive") {
        $Icon = $blueFileIcon
    } else {
        $Icon = $redFileIcon
    }

    $script:icon.Icon = $Icon
    $script:icon.Text = $Text
}


function Show-Message {
    Param (
        [String]$Title,

        [String]$Message
    )

    $fallbackNotification = @"
        Import-Module psui1 -Force -DisableNameChecking
        Set-UIConsoleTitle "'$Title'"
        Set-UIConsoleIcon "'$redFileIcon'"
        Set-UIConsoleWidth 100
        Set-UIConsoleHeight 18
        Set-UIBufferSize 100 18
        Write-UIPaintedScreen "DarkRed"
        Set-UIConsoleColor "DarkRed "White"
        Write-Host "'`n`n  $Message`n'"

        `$oldY = (Get-UICursorPositionY)
        Set-UIFocusedWindow -WindowTitle "'$Title'"
        Set-UICursorPosition 0 ((Get-UIConsoleHeight) - 1)
        Write-Host ("' '" * (Get-UIConsoleWidth))
        Set-UICursorPosition -X 1 -Y `$oldY
        Wait-AnyKey
"@
    if ($Message -match "#") {
        $Title = $Message.split("#")[0]
        $Message = $Message.split("#")[1]
    }
    if (Get-Command "New-BurntToastNotification" -ErrorAction SilentlyContinue) {
        New-BurntToastNotification -AppLogo $redFileIcon -Text $Title, $Message
    } else {
        Start Powershell $fallbackNotification
    }
}


if ($Alert -and $Message) {
    Show-Message $Title $Message
} elseif ($Install) {
    Install-LockdownClientTask
} elseif ($Service) {
    Show-LockdownClientIcon
    $alertedOnDeadPulse = $false
    $config = Get-LockdownPolicy
    while ($true) {
        Start-Sleep 5
        Update-LockdownClientIcon

        if (Test-Path $config.AlertFilePath) {
            $alertMessage = Get-Content $config.AlertFilePath
            if ($alertMessage) {
                LockdownClient -Alert -Message $alertMessage
                Write-Host "" > $config.AlertFilePath
            }
        }

        $pulse = Get-LockdownPulse
        if ($pulse -eq "Dead" -and -not $alertedOnDeadPulse) {
            if (-not ((Get-LastWakeTime) -lt (Date).AddSeconds(-10)) -or (Get-Item $config.StatusFilePath).LastWriteTime -gt (Date).AddSeconds(-30)) {
                continue
            }
            LockdownClient -Alert -Title "Lockdown not running" -Message "Lockdown does not appear to be running as no pulse has been recorded for more than thrity seconds."
            $alertedOnDeadPulse = $true
        } elseif ($pulse -eq "Alive") {
            $alertedOnDeadPulse = $false
        }
    }
} else {
    Get-Help LockdownClient
}
