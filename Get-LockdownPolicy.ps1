# Lockdown is a system hardening tool which applies, enforces, and reports on
# various system hardening settings according to a "lockdown policy". For
# example, it can lock the system when various USB devices are inserted, and
# send alerts when backups are out of date or pre-defined anti-virus settings
# and components are disabled.
#
# This file is used to retrieve the Lockdown policy. It must be run as an
# administrator.
#
# Copyright (C) jdgregson, 2019
# Author: Jonathan Gregson <jonathan@jdgregson.com>

Param (
    [switch]$DeviceWhitelistPath,
    [switch]$LogPath,
    [switch]$StatusFilePath,
    [switch]$AlertFilePath,
    [switch]$LockOnNewDevice,
    [switch]$DisableNewDevice,
    [switch]$USBStorage,
    [switch]$Status,
    [switch]$Unapplied,
    [switch]$Default
)


function Get-DefaultPolicy {
    return New-Object -Type PSObject -Property @{
        DeviceWhitelistPath = "C:\lockdown\etc\whitelist"
        LogPath = "C:\lockdown\var\lockdown.log"
        StatusFilePath = "C:\lockdown\var\lockdown.status"
        AlertFilePath = "C:\lockdown\var\lockdown.alert"
        LockOnNewDevice = "TRUE"
        DisableNewDevice = "TRUE"
        USBStorage = "BLOCKED"
        Status = "ENABLED"
        Unapplied = "FALSE"
    }
}


function Get-SavedPolicy {
    if (($env:LockdownConfig -ne $Null) -and (Test-Path $env:LockdownConfig)) {
        $config = Import-CliXml $env:LockdownConfig
    }
    if (-not($config) -or $config.GetType().Name -ne "PSCustomObject") {
        Write-Warning "No valid config found at '$env:LockdownConfig' -- Loading default config"
        $config = Get-DefaultPolicy
    }
    return $config
}


$config = Get-SavedPolicy
if ($Default) {
    $config = Get-DefaultPolicy
}
if ($DeviceWhitelistPath) {
    return $config.DeviceWhitelistPath
} elseif ($LogPath) {
    return $config.LogPath
} elseif ($StatusFilePath) {
    return $config.StatusFilePath
} elseif ($AlertFilePath) {
    return $config.AlertFilePath
} elseif ($LockOnNewDevice) {
    return $config.LockOnNewDevice
} elseif ($DisableNewDevice) {
    return $config.DisableNewDevice
} elseif ($ActionOnNetAdapter) {
    return $config.ActionOnNetAdapter
} elseif ($USBStorage) {
    return $config.USBStorage
} elseif ($Status) {
    return $config.Status
} elseif ($Unapplied) {
    return $config.Unapplied
} else {
    return $config
}
