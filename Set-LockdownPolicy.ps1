# Lockdown is a system hardening tool which applies, enforces, and reports on
# various system hardening settings according to a "lockdown policy". For
# example, it can lock the system when various USB devices are inserted, and
# send alerts when backups are out of date or pre-defined anti-virus settings
# and components are disabled.
#
# This file is used to configure and apply the Lockdown policy. It must be run
# as an administrator.
#
# Copyright (C) jdgregson, 2019
# Author: Jonathan Gregson <jonathan@jdgregson.com>

Param (
    [string]$Catchall,
    [string]$DeviceWhitelistPath,
    [string]$LogPath,
    [string]$StatusFilePath,
    [string]$AlertFilePath,
    [string]$LockOnNewDevice,
    [string]$DisableNewDevice,
    [string]$USBStorage,
    [string]$Status,
    [string]$Unapplied,
    [switch]$NoReload,
    [string]$LogLevel,
    [switch]$Default
)


function Save-NewPolicy {
    Param (
        [object]$config
    )

    $config | Export-CliXml $env:LockdownConfig
}


$config = Get-LockdownPolicy
$config.Unapplied = "TRUE"
if ($DeviceWhitelistPath) {
    if (-not(Test-Path $DeviceWhitelistPath)) {
        Write-Warning "Could not find path `"$DeviceWhitelistPath`"."
    }
    Lockdown -Log "Changing DeviceWhitelistPath policy: $($config.DeviceWhitelistPath) -> $DeviceWhitelistPath"
    $config.DeviceWhitelistPath = $DeviceWhitelistPath
}
if ($LogPath) {
    if (-not(Test-Path $LogPath)) {
        Write-Warning "Could not find path `"$LogPath`"."
    }
    Lockdown -Log "Changing LogPath policy: $($config.LogPath) -> $LogPath"
    $config.LogPath = $LogPath
}
if ($LogLevel) {
    if ("MESSAGE" -eq $LogLevel) {
        $config.LogLevel = "MESSAGE"
    } elseif ("VERBOSE" -eq $LogLevel) {
        $config.LogLevel = "VERBOSE"
    } else {
        Write-Warning "LogLevel does not support `"$LogLevel`" as a policy. Please use `"MESSAGE`" or `"VERBOSE`""
    }
}
if ($StatusFilePath) {
    if (-not(Test-Path $StatusFilePath)) {
        Write-Warning "Could not find path `"$StatusFilePath`"."
    }
    Lockdown -Log "Changing StatusFilePath policy: $($config.StatusFilePath) -> $StatusFilePath"
    $config.StatusFilePath = $StatusFilePath
}
if ($AlertFilePath) {
    if (-not(Test-Path $AlertFilePath)) {
        Write-Warning "Could not find path `"$AlertFilePath`"."
    }
    Lockdown -Log "Changing AlertFilePath policy: $($config.AlertFilePath) -> $StatusFilePath"
    $config.AlertFilePath = $AlertFilePath
}
if ($LockOnNewDevice) {
    if ($LockOnNewDevice -eq "TRUE") {
        Lockdown -Log "Changing LockOnNewDevice policy: $($config.LockOnNewDevice) -> $LockOnNewDevice"
        $config.LockOnNewDevice = "TRUE"
    } elseif ($LockOnNewDevice -eq "FALSE") {
        Lockdown -Log "Changing LockOnNewDevice policy: $($config.LockOnNewDevice) -> $LockOnNewDevice"
        $config.LockOnNewDevice = "FALSE"
    } else {
        Lockdown -Log "Error changing LockOnNewDevice policy: `"$LockOnNewDevice`" is not a valid option"
        Write-Warning "LockOnNewDevice does not support `"$LockOnNewDevice`" as a policy. Please use `"LOCK`" or `"LOG`""
    }
}
if ($DisableNewDevice) {
    if ($DisableNewDevice -eq "TRUE") {
        Lockdown -Log "Changing DisableNewDevice policy: $($config.DisableNewDevice) -> $DisableNewDevice"
        $config.DisableNewDevice = "TRUE"
    } elseif ($DisableNewDevice -eq "FALSE") {
        Lockdown -Log "Changing DisableNewDevice policy: $($config.DisableNewDevice) -> $DisableNewDevice"
        $config.DisableNewDevice = "FALSE"
    } else {
        Lockdown -Log "Error changing DisableNewDevice policy: `"$DisableNewDevice`" is not a valid option"
        Write-Warning "DisableNewDevice does not support `"$DisableNewDevice`" as a policy. Please use `"LOCK`" or `"LOG`""
    }
}
if ($USBStorage) {
    if (("BLOCK", "BLOCKED", "DISABLE", "DISABLED") -contains $USBStorage) {
        Lockdown -Log "Changing USBStorage policy: $($config.USBStorage) -> $USBStorage"
        $config.USBStorage = "BLOCKED"
    } elseif (("UNBLOCK", "UNBLOCKED", "ENABLE", "ENABLED") -contains $USBStorage) {
        Lockdown -Log "Changing USBStorage policy: $($config.USBStorage) -> $USBStorage"
        $config.USBStorage = "UNBLOCKED"
    } else {
        Lockdown -Log "Error changing USBStorage policy: `"$USBStorage`" is not a valid option"
        Write-Warning "USBStorage does not support `"$USBStorage`" as a policy. Please use `"BLOCKED`" or `"UNBLOCKED`""
    }
}
if ($Status) {
    if (("ENABLE", "ENABLED") -contains $Status) {
        $config.Status = "ENABLED"
    } elseif (("DISABLE", "DISABLED") -contains $Status) {
        $config.Status = "DISABLED"
    } else {
        Write-Warning "Status does not support `"$Status`" as a policy. Please use `"ENABLED`" or `"DISABLED`""
    }
}
if ($Unapplied) {
    if ("FALSE" -eq $Unapplied) {
        $config.Unapplied = "FALSE"
    } elseif ("TRUE" -eq $Unapplied) {
        $config.Unapplied = "TRUE"
    } else {
        Write-Warning "Unapplied does not support `"$Unapplied`" as a policy. Please use `"TRUE`" or `"FALSE`""
    }
}
if ($Default) {
    Lockdown -Log "Restoring default policy"
    $config = Get-LockdownPolicy -Default
}


if (-not([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
        [Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "The lockdown policy can only be set by an administrator."
    return
} else {
    Save-NewPolicy $config
    if (-not($NoReload)) {
        $config.Unapplied = "FALSE"
        Save-NewPolicy $config
        Lockdown -Reload
    }
}
