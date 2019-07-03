# Lockdown is a system hardening tool which applies, enforces, and reports on
# various system hardening settings according to a "lockdown policy". For
# example, it can lock the system when various USB devices are inserted, and
# send alerts when backups are out of date or pre-defined anti-virus settings
# and components are disabled.
#
# This file is the core of the Lockdown system. When called with no arguments,
# it will apply settings according to the policy and continue to run while
# waiting for events. It is intended to be run via a schedules task which is not
# visible to standard users.
#
# Copyright (C) jdgregson, 2019
# Author: Jonathan Gregson <jonathan@jdgregson.com>

Param (
    [switch]$Install,
    [switch]$Disable,
    [switch]$Enable,
    [switch]$Reload,
    [switch]$Status,
    [switch]$Lock,
    [string]$Message,
    [string]$Alert,
    [switch]$GetLog,
    [string]$Log,
    [string]$LogVerbose,
    [switch]$GetWhitelist,
    [string]$Whitelist,
    [string]$CheckWhitelist,
    [switch]$EditWhitelist,
    [switch]$Pulse,
    [switch]$SetConfigPath,
    [switch]$Service
)


$USBStorageKey = "HKLM:\SYSTEM\CurrentControlSet\Services\usbstor\"
$USBStorageName = "Start"
$URBStorageDisableValue = 4
$URBStorageEnableValue = 3


function Get-Whitelist {
    Get-Content $config.DeviceWhitelistPath
}


function Add-ToWhitelist {
    Param (
        [string]$DeviceID
    )

    $DeviceID | Add-Content $config.DeviceWhitelistPath -Encoding "UTF8"
    (Get-Content $config.DeviceWhitelistPath) -split "`n" | Sort-Object | Set-Content $config.DeviceWhitelistPath -Encoding "UTF8"

    $logEntries = Get-Content $config.LogPath
    $logEntries = $logEntries -replace $DeviceID,"***"
    $logEntries | Set-Content $config.LogPath -Encoding "UTF8"
}


function Test-Whitelist {
    Param (
        [string]$ID
    )

    $whitelist = (Get-Whitelist)
    if ($whitelist -contains $ID) {
        return "TRUE"
    }

    $wildcardWhitelist = @($whitelist | ? {$_ -match "\*"})
    for ($i = 0; $i -lt $wildcardWhitelist.length; $i++) {
        $testItem = @($wildcardWhitelist[$i] -split "\*")
        $allMatch = $true
        for ($j = 0; $j -lt $testItem.length; $j++) {
            if (-not($id -match [Regex]::Escape($testItem[$j]))) {
                $allMatch = $false
            }
        }
        if ($allMatch) {
            return "TRUE"
        }
    }

    return "FALSE"
}


function Edit-Whitelist {
    notepad.exe $config.DeviceWhitelistPath
}


function Lock-Workstation {
    $user = ((quser) -replace '^>', '') -replace '\s{2,}', ',' | ConvertFrom-Csv
    tsdiscon $user.ID
    Write-LogMessage "Attempted to lock the workstation"
}


function Get-Log {
    Get-Content $config.LogPath
}


function Write-LogMessage {
    Param (
        [string]$message,
        [string]$logLevel = "message"
    )

    $timestamp = $(Get-Date -UFormat  "[%m/%d/%Y %H:%M:%S]")
    if ($message) {
        if ($logLevel -eq "message") {
            "$timestamp` [M]: $message" | Add-Content $config.LogPath -Encoding "UTF8"
        } elseif ($logLevel -eq "verbose" -and $config.LogLevel -eq "verbose") {
            "$timestamp` [V]: $message" | Add-Content $config.LogPath -Encoding "UTF8"
        }
    }
}


function Show-Message {
    Param (
        [string]$message
    )

    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show($message, 'Lockdown', 'OK','Error')
}


function Send-AlertToClient {
    Param (
        [string]$message
    )

    $message > $config.AlertFilePath
}


function Get-LockdownTask {
    try {Get-ScheduledTask "Lockdown" *>&1} catch {$_}
}


function Get-LockdownConfigPath {
    return $env:LockdownConfig
}


function Set-LockdownConfigPath {
    Param (
        [string]$path
    )

    $env:LockdownConfig = "$path"
    [System.Environment]::SetEnvironmentVariable("LOCKDOWNCONFIG", "$path", [System.EnvironmentVariableTarget]::User)
}


function Get-LockdownStatus {
    $scheduledTask = (Get-LockdownTask)
    if ($scheduledTask.getType().Name -eq "CimInstance") {
        if($scheduledTask.State -eq "Running") {
            "Enabled"
        } else {
            "Disabled"
        }
    } else {
        "N/A"
    }
}


function Get-Pulse {
    $content = (Get-Content $config.StatusFilePath)
    $i = 0
    while ($content -eq $Null -and $i -lt 10) {
        sleep 0.1
        $content = (Get-Content $config.StatusFilePath)
        $i++
    }

    $beat = (Date($content)) -ge (Date).AddSeconds(-2)
    if ($beat) {
        return "Alive"
    } else {
        return "Dead"
    }
}


function Install-LockdownTask {
    Param (
        [string]$TaskName = "Lockdown"
    )

    if (-not([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
            [Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Warning "The lockdown scheduled task can only be installed by an administrator."
        return
    }

    $configPath = (Get-LockdownConfigPath)
    if ($configPath -eq $Null -or $configPath -eq "") {
        Set-LockdownConfigPath (Read-Host "The Lockdown config path is currently not set. Enter the path to your config file")
    } else {
        $prompt = Read-Host "The Lockdown config path is currently set to `"$configPath`". Would you like to change it? (y/N)"
        if ($prompt -eq "y") {
            Set-LockdownConfigPath (Read-Host "Enter the path to your config file")
        }
    }

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
        -Argument "-ExecutionPolicy Bypass -File `"$PSScriptRoot\Start-Lockdown.ps1`""
    $principal = New-ScheduledTaskPrincipal -UserID "$env:USERDOMAIN\$env:USERNAME" -LogonType S4U -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet
    $settings.DisallowStartIfOnBatteries = $False
    $settings.StopIfGoingOnBatteries = $False
    $settings.Hidden = $True
    $settings.ExecutionTimeLimit = "PT0S"
    $settings.StartWhenAvailable = $True
    $settings.AllowHardTerminate = $False
    $trigger =  New-ScheduledTaskTrigger -AtStartup
    $task = Register-ScheduledTask -Action $action -Trigger $trigger -TaskName $TaskName -Settings $settings -Principal $principal

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


function Start-LockdownTask {
    $scheduledTask = (Get-LockdownTask)
    if ($scheduledTask.getType().Name -eq "CimInstance") {
        $scheduledTask | Start-ScheduledTask
    } else {
        "Error: task not found. Are you an administrator?"
    }
}


function Stop-LockdownTask {
    $scheduledTask = (Get-LockdownTask)
    if ($scheduledTask.getType().Name -eq "CimInstance") {
        $scheduledTask | Stop-ScheduledTask
    } else {
        "Error: task not found. Are you an administrator?"
    }
}


function Enable-Lockdown {
    $Query = "SELECT * FROM __InstanceCreationEvent Within 1 WHERE TargetInstance ISA 'Win32_PnPEntity'"
    Register-WmiEvent -Query $Query -SourceIdentifier "LockdownQuery" -Action {
        $id = $EventArgs.NewEvent.TargetInstance["DeviceID"]
        if ((Lockdown -CheckWhitelist "$id") -eq "TRUE") {
            Lockdown -LogVerbose "Whitelisted device detected."
        } else {
            Lockdown -Log "New device detected. DeviceID: $id"
            if ((Get-LockdownPolicy -LockOnNewDevice) -eq "TRUE") {
                Lockdown -Lock
                Lockdown -Alert "New device detected#DeviceID: $id"
            }
            if ((Get-LockdownPolicy -DisableNewDevice) -eq "TRUE") {
                $result = (Disable-PnPDevice -InstanceID ($EventArgs.NewEvent.TargetInstance["DeviceID"]) -Confirm:$False -PassThru)
                if ($result.Status -eq "OK") {
                    Lockdown -Log "Successfully disabled device: $id"
                } else {
                    Lockdown -Log "[ERROR] Failed to disabled device: $id"
                }
            }
        }
    }

    if ($config.USBStorage -eq "BLOCKED") {
        Set-ItemProperty -Path $USBStorageKey -Name $USBStorageName -Value $URBStorageDisableValue
    } elseif ($config.USBStorage -eq "UNBLOCKED") {
        Set-ItemProperty -Path $USBStorageKey -Name $USBStorageName -Value $URBStorageEnableValue
    }
}


$config = Get-LockdownPolicy
if ($Install) {
    Install-LockdownTask
} elseif ($Disable) {
    Set-LockdownPolicy -Status "DISABLED"
    Write-LogMessage "Stopped due to user request"
} elseif ($Enable) {
    Set-LockdownPolicy -Status "ENABLED"
    Write-LogMessage "Started due to user request"
} elseif ($GetWhitelist) {
    return Get-Whitelist
} elseif ($Whitelist) {
    Add-ToWhitelist $Whitelist
} elseif ($CheckWhitelist) {
    Test-Whitelist $CheckWhitelist
} elseif ($EditWhitelist) {
    Edit-Whitelist
} elseif ($Reload) {
    Stop-LockdownTask
    Start-LockdownTask
    Write-LogMessage "Reloaded due to user request"
} elseif ($Lock) {
    Lock-Workstation
} elseif ($Status) {
    Get-LockdownStatus
} elseif ($Message) {
    Show-Message $Message
} elseif ($Alert) {
    Send-AlertToClient $Alert
} elseif ($GetLog) {
    Get-Log
} elseif ($Log) {
    Write-LogMessage $Log
} elseif ($LogVerbose) {
    Write-LogMessage $LogVerbose -LogLevel "verbose"
}  elseif ($Pulse) {
    Get-Pulse
} elseif ($SetConfigPath) {
    Set-LockdownConfigPath (Read-Host "Enter the path to your config file")
} elseif ($Service) {
    Write-LogMessage "Lockdown is starting..."
    Set-LockdownPolicy -Unapplied "FALSE" -NoReload
    if ($config.Status -eq "ENABLED") {
        Enable-Lockdown
        While ($True) {
            (Date).toString() > $config.StatusFilePath
            Sleep 1
        }
    }
} else {
    Get-Help Lockdown
}
