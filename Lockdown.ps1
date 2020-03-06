# File: Lockdown.ps1
# Project: Lockdown, https://github.com/jdgregson/Lockdown
# Copyright (C) Jonathan Gregson, 2020
# Author: Jonathan Gregson <jonathan@jdgregson.com>

Param (
    [Switch]$Install,

    [Switch]$Disable,

    [Switch]$Enable,

    [Switch]$Reload,

    [Switch]$Status,

    [Switch]$Lock,

    [String]$Message,

    [String]$Alert,

    [Switch]$GetLog,

    [String]$Log,

    [String]$LogVerbose,

    [Switch]$GetDeviceWhitelist,

    [Switch]$GetCredentialEventWhitelist,

    [String]$WhitelistDevice,

    [String]$WhitelistCredentialEvent,

    [String]$CheckDeviceWhitelist,

    [String]$CheckCredentialEventWhitelist,

    [Switch]$EditDeviceWhitelist,

    [Switch]$EditCredentialEventWhitelist,

    [Switch]$Pulse,

    [Switch]$SetPolicyPath,

    [Switch]$Service
)


$USBStorageKey = "HKLM:\SYSTEM\CurrentControlSet\Services\usbstor\"
$USBStorageName = "Start"
$USBStorageDisableValue = 4
$USBStorageEnableValue = 3


function Get-DeviceWhitelist {
    Get-Content $policy.DeviceWhitelistPath
}


function Get-CredentialEventWhitelist {
    Get-Content $policy.CredentialEventWhitelistPath
}


function AddTo-DeviceWhitelist {
    Param (
        [String]$DeviceID
    )

    $DeviceID | Add-Content $policy.DeviceWhitelistPath -Encoding "UTF8"
    (Get-Content $policy.DeviceWhitelistPath) -split "`n" | Sort-Object | Set-Content $policy.DeviceWhitelistPath -Encoding "UTF8"

    $logEntries = Get-Content $policy.LogPath
    $logEntries = $logEntries -replace $DeviceID,"***"
    $logEntries | Set-Content $policy.LogPath -Encoding "UTF8"
}


function AddTo-CredentialEventWhitelist {
    Param (
        [String]$ProcessPath
    )

    $ProcessPath | Add-Content $policy.CredentialEventWhitelistPath -Encoding "UTF8"
    (Get-Content $policy.CredentialEventWhitelistPath) -split "`n" | Sort-Object | Set-Content $policy.CredentialEventWhitelistPath -Encoding "UTF8"
}


function Test-Whitelist {
    Param (
        [String]$Search,

        [String[]]$Whitelist
    )

    if ($Whitelist -contains $Search) {
        return $true
    }

    # Test for wildcard matches by splitting whitelist entries at '*' and
    # checking if each section is in the search.
    $wildcardWhitelist = @($Whitelist | Where-Object {$_ -match "\*"})
    for ($i = 0; $i -lt $wildcardWhitelist.length; $i++) {
        $testItem = @($wildcardWhitelist[$i] -split "\*")
        $allMatch = $true
        for ($j = 0; $j -lt $testItem.length; $j++) {
            if (-not($Search -match [Regex]::Escape($testItem[$j]))) {
                $allMatch = $false
            }
        }
        if ($allMatch) {
            return $true
        }
    }

    return $false
}


function Edit-DeviceWhitelist {
    notepad.exe $policy.DeviceWhitelistPath
}


function Edit-CredentialEventWhitelist {
    notepad.exe $policy.CredentialEventWhitelistPath
}


function Lock-Workstation {
    $user = ((quser) -replace "^>", "") -replace "\s{2,}", "," | ConvertFrom-Csv
    tsdiscon $user.ID
    Write-LogMessage "Attempted to lock the workstation"
}


function Get-Log {
    Get-Content $policy.LogPath
}


function Write-LogMessage {
    Param (
        [String]$Message,

        [String]$LogLevel = "message"
    )

    $timestamp = $(Get-Date -UFormat "[%m/%d/%Y %H:%M:%S]")
    if ($Message) {
        if ($LogLevel -eq "message") {
            "$timestamp` [M]: $Message" | Add-Content $policy.LogPath -Encoding "UTF8"
        } elseif ($LogLevel -eq "verbose" -and $policy.LogLevel -eq "verbose") {
            "$timestamp` [V]: $Message" | Add-Content $policy.LogPath -Encoding "UTF8"
        }
    }
}


function Show-Message {
    Param (
        [String]$Message
    )

    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show($Message, "Lockdown", "OK", "Error")
}


function Send-AlertToClient {
    Param (
        [String]$Message
    )

    $Message > $policy.AlertFilePath
}


function Get-LockdownTask {
    try {
        Get-ScheduledTask "Lockdown" *>&1
    } catch {
        $_
    }
}


function Get-LockdownPolicyPath {
    return $env:LockdownPolicyPath
}


function Set-LockdownPolicyPath {
    Param (
        [String]$Path
    )

    $env:LockdownPolicyPath = $Path
    [System.Environment]::SetEnvironmentVariable("LockdownPolicyPath", $Path, [System.EnvironmentVariableTarget]::User)
}


function Get-LockdownStatus {
    $scheduledTask = Get-LockdownTask
    if ($scheduledTask.getType().Name -eq "CimInstance") {
        if ($scheduledTask.State -eq "Running") {
            "Enabled"
        } else {
            "Disabled"
        }
    } else {
        "N/A"
    }
}


function Get-Pulse {
    $content = Get-Content $policy.StatusFilePath
    $i = 0
    while ($content -eq $null -and $i -lt 10) {
        Start-Sleep 0.1
        $content = Get-Content $policy.StatusFilePath
        $i++
    }

    $beat = (Date($content)) -ge (Date).AddSeconds(-2)
    if ($beat) {
        "Alive"
    } else {
        "Dead"
    }
}


function Test-UserIsAdmin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")
}


function Install-LockdownTask {
    Param (
        [String]$TaskName = "Lockdown"
    )

    if (-not (Test-UserIsAdmin)) {
        Write-Warning "The lockdown scheduled task can only be installed by an administrator."
        return
    }

    $policyPath = Get-LockdownPolicyPath
    if ($policyPath -eq $null -or $policyPath -eq "") {
        Set-LockdownPolicyPath (Read-Host "The Lockdown policy path is currently not set. Enter the path to your policy file")
    } else {
        $prompt = Read-Host "The Lockdown policy path is currently set to `"$policyPath`". Would you like to change it? (y/N)"
        if ($prompt -eq "y") {
            Set-LockdownPolicyPath (Read-Host "Enter the path to your policy file")
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
        $task | Unregister-ScheduledTask -Confirm:$false
    }
    Write-Host "Installing new scheduled task `"$TaskName`"..."
    $action = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument "-ExecutionPolicy Bypass -File `"$PSScriptRoot\Start-Lockdown.ps1`""
    $principal = New-ScheduledTaskPrincipal -UserID "$env:USERDOMAIN\$env:USERNAME" -LogonType S4U -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet
    $settings.DisallowStartIfOnBatteries = $false
    $settings.StopIfGoingOnBatteries = $false
    $settings.Hidden = $true
    $settings.ExecutionTimeLimit = "PT0S"
    $settings.StartWhenAvailable = $true
    $settings.AllowHardTerminate = $false
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $task = Register-ScheduledTask -Action $action -Trigger $trigger -TaskName $TaskName -Settings $settings -Principal $principal

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


function Start-LockdownTask {
    $scheduledTask = Get-LockdownTask
    if ($scheduledTask.getType().Name -eq "CimInstance") {
        $scheduledTask | Start-ScheduledTask
    } else {
        "Error: task not found. Are you an administrator?"
    }
}


function Stop-LockdownTask {
    $scheduledTask = Get-LockdownTask
    if ($scheduledTask.getType().Name -eq "CimInstance") {
        $scheduledTask | Stop-ScheduledTask
    } else {
        "Error: task not found. Are you an administrator?"
    }
}


function Enable-Lockdown {
    # Subscribe to WMI events about PnP devices
    $WMIQuery = "SELECT * FROM __InstanceCreationEvent Within 1 WHERE TargetInstance ISA 'Win32_PnPEntity'"
    Register-WmiEvent -Query $WMIQuery -SourceIdentifier "LockdownWMIEventSubscription-$instanceId" -Action {
        $localId = New-Guid
        $id = $EventArgs.NewEvent.TargetInstance["DeviceID"]
        if (Lockdown -CheckDeviceWhitelist $id) {
            Lockdown -LogVerbose "Whitelisted device detected."
        } else {
            Lockdown -Log "New device detected. DeviceID: $id"
            if ((Get-LockdownPolicy -LockOnNewDevice) -eq $true) {
                Lockdown -Lock
                Lockdown -Alert "New device detected#DeviceID: $id"
            }
            if ((Get-LockdownPolicy -DisableNewDevice) -eq $true) {
                $result = (Disable-PnPDevice -InstanceID ($EventArgs.NewEvent.TargetInstance["DeviceID"]) -Confirm:$false -PassThru)
                if ($result.Status -eq "OK") {
                    Lockdown -Log "Successfully disabled device: $id"
                } else {
                    Lockdown -Log "[ERROR] Failed to disabled device: $id"
                }
            }
        }
    }

    # Subscribe to events about Credential Manager access
    $SecurityLog = Get-EventLog -List | Where-Object {$_.Log -eq "Security"}
    Register-ObjectEvent -InputObject $SecurityLog -SourceIdentifier "LockdownCredentialGuardEventSubscription-$instanceId" -EventName EntryWritten -Action {
        $entry = $event.SourceEventArgs.Entry
        $eventId = $entry.EventID
        $credentialGuardEventIds = 5379, 5380, 5381, 5382
        if ($credentialGuardEventIds -contains $eventId) {
            $localId = New-Guid
            $lastEvent = Get-WinEvent -FilterHashtable @{LogName="Security";Id=$eventId} -MaxEvents 1
            $eventXml = ([xml]$lastEvent.ToXml()).Event
            $eventXml.EventData.Data | ForEach-Object {
                if ($_.Name -eq "ClientProcessId") {
                    $clientPid = $_."#text"
                }
            }
            $hexPID = "0x" + [System.Convert]::ToString($clientPid, 16)
            $processCreation = Get-WinEvent -FilterXPath "*[System[EventID=4688] and EventData[Data[@Name='NewProcessId']='$hexPID']]" -LogName "Security" -MaxEvents 1 -ErrorAction SilentlyContinue
            if ($processCreation) {
                $eventXml = ([xml]$processCreation.ToXml()).Event
                $processPath = ($eventXml.EventData.Data | Where-Object {$_.Name -eq "NewProcessName"})."#text"
                $processName = $processPath | Split-Path -Leaf
            } else {
                $processPath = "N/A"
                $processName = "N/A"
            }

            $backoff = $false
            $backoffTimeout = (Get-LockdownPolicy -CredentialEventBackoffTimeout)
            if (-not $script:credentialEventBackoffList) {
                $script:credentialEventBackoffList = @()
            }
            if ($backoffTimeout) {
                # Remove expired entries from the backoff list
                $backoffList = @($script:credentialEventBackoffList | Where-Object {
                    $_.StartTime.AddSeconds($backoffTimeout) -gt (Get-Date)
                })
                # Check if this process is on the backoff list
                $backoffList | ForEach-Object {
                    if ($_.TestString -eq $processPath) {
                        $backoff = $true
                    }
                }
                # Add this process to the backoff list if not already on it
                if (-not $backoff -and $processPath -ne "N/A") {
                    $backoffList += New-Object -Type PSObject -Property @{
                        StartTime = (Get-Date)
                        TestString = $processPath
                    }
                }
                $script:credentialEventBackoffList = $backoffList
            }
            if ((Get-LockdownPolicy -AuditCredentialEvents) -eq $true) {
                $message = "$(Get-Date), Event ID: $eventId, Process ID: $clientPid, Process Name: $processName, Process Path: $processPath"
                $message | Add-Content (Get-LockdownPolicy -CredentialEventAuditLogPath) -Encoding "UTF8"
            }
            if (-not $backoff) {
                if ((Lockdown -CheckCredentialEventWhitelist $processPath) -eq $false) {
                    if ((Get-LockdownPolicy -AlertOnCredentialEvents) -eq $true) {
                        $message = "A process has accessed the Credential Manager. Process: $processPath"
                        Lockdown -Alert $message
                    }
                }
            }
        }
    }

    # Enable or disable USB devices
    if ($policy.DisableUSBStorage) {
        Set-ItemProperty -Path $USBStorageKey -Name $USBStorageName -Value $USBStorageDisableValue
    } else {
        Set-ItemProperty -Path $USBStorageKey -Name $USBStorageName -Value $USBStorageEnableValue
    }
}


$policy = Get-LockdownPolicy
$instanceId = New-Guid
if ($Install) {
    Install-LockdownTask
} elseif ($Disable) {
    Set-LockdownPolicy -LockdownEnabled $false
    Write-LogMessage "Stopped due to user request"
} elseif ($Enable) {
    Set-LockdownPolicy -LockdownEnabled $true
    Write-LogMessage "Started due to user request"
} elseif ($GetDeviceWhitelist) {
    Get-DeviceWhitelist
} elseif ($GetCredentialEventWhitelist) {
    Get-CredentialEventWhitelist
} elseif ($WhitelistDevice) {
    AddTo-DeviceWhitelist $WhitelistDevice
} elseif ($WhitelistCredentialEvent) {
    AddTo-CredentialEventWhitelist $WhitelistCredentialEvent
} elseif ($CheckDeviceWhitelist) {
    Test-Whitelist $CheckDeviceWhitelist (Get-DeviceWhitelist)
} elseif ($CheckCredentialEventWhitelist) {
    Test-Whitelist $CheckCredentialEventWhitelist (Get-CredentialEventWhitelist)
} elseif ($EditDeviceWhitelist) {
    Edit-DeviceWhitelist
} elseif ($EditCredentialEventWhitelist) {
    Edit-CredentialEventWhitelist
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
} elseif ($Pulse) {
    Get-Pulse
} elseif ($SetPolicyPath) {
    Set-LockdownPolicyPath (Read-Host "Enter the path to your policy file")
} elseif ($Service) {
    Start-Transcript -Path "C:\lockdown\var\lockdown-transcript-$instanceId.log" -IncludeInvocationHeader
    Write-LogMessage "Lockdown is starting, instanceId: $instanceId..."
    Set-LockdownPolicy -Unapplied $false -NoReload
    if ($policy.LockdownEnabled) {
        Enable-Lockdown
        while ($true) {
            try {
                (Date).toString() > $policy.StatusFilePath
            } catch {
            }
            Start-Sleep 1
        }
    }
} else {
    Get-Help Lockdown
}
