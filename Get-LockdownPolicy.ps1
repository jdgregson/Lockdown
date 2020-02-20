# File: Get-LockdownPolicy.ps1
# Project: Lockdown, https://github.com/jdgregson/Lockdown
# Copyright (C) Jonathan Gregson, 2020
# Author: Jonathan Gregson <jonathan@jdgregson.com>

Param (
    [Switch]$DeviceWhitelistPath,

    [Switch]$LogPath,

    [Switch]$StatusFilePath,

    [Switch]$AlertFilePath,

    [Switch]$LockOnNewDevice,

    [Switch]$DisableNewDevice,

    [Switch]$DisableUSBStorage,

    [Switch]$AuditCredentialEvents,

    [Switch]$AlertOnCredentialEvents,

    [Switch]$CredentialEventAuditLogPath,

    [Switch]$CredentialEventWhitelistPath,

    [Switch]$LockdownEnabled,

    [Switch]$Unapplied,

    [Switch]$NoReload,

    [Switch]$LogLevel,

    [Switch]$Default
)


function Get-DefaultPolicy {
    New-Object -Type PSObject -Property @{
        DeviceWhitelistPath = "C:\lockdown\etc\whitelist"
        LogPath = "C:\lockdown\var\lockdown.log"
        LogLevel = "MESSAGE"
        StatusFilePath = "C:\lockdown\var\lockdown.status"
        AlertFilePath = "C:\lockdown\var\lockdown.alert"
        LockOnNewDevice = $false
        DisableNewDevice = $false
        DisableUSBStorage = $false
        AuditCredentialEvents = $false
        AlertOnCredentialEvents = $false
        CredentialEventAuditLogPath = "C:\lockdown\var\credential-event-audit.log"
        CredentialEventWhitelistPath = "C:\lockdown\etc\credential-event-whitelist"
        LockdownEnabled = $true
        Unapplied = $false
    }
}


function Get-SavedPolicy {
    if (($env:LockdownConfig -ne $null) -and (Test-Path $env:LockdownConfig)) {
        $config = Import-CliXml $env:LockdownConfig
    }
    if (-not $config -or $config.GetType().Name -ne "PSCustomObject") {
        Write-Warning "No valid config found at `"$env:LockdownConfig`" -- Loading default config"
        $config = Get-DefaultPolicy
    }
    $config
}


$config = Get-SavedPolicy
if ($Default) {
    $config = Get-DefaultPolicy
}
if ($DeviceWhitelistPath) {
    $config.DeviceWhitelistPath
} elseif ($LogPath) {
    $config.LogPath
} elseif ($LogLevel) {
    $config.LogLevel
} elseif ($StatusFilePath) {
    $config.StatusFilePath
} elseif ($AlertFilePath) {
    $config.AlertFilePath
} elseif ($LockOnNewDevice) {
    $config.LockOnNewDevice
} elseif ($DisableNewDevice) {
    $config.DisableNewDevice
} elseif ($DisableUSBStorage) {
    $config.DisableUSBStorage
} elseif ($AuditCredentialEvents) {
    $config.AuditCredentialEvents
} elseif ($AlertOnCredentialEvents) {
    $config.AlertOnCredentialEvents
} elseif ($CredentialEventAuditLogPath) {
    $config.CredentialEventAuditLogPath
} elseif ($CredentialEventWhitelistPath) {
    $config.CredentialEventWhitelistPath
} elseif ($LockdownEnabled) {
    $config.LockdownEnabled
} elseif ($Unapplied) {
    $config.Unapplied
} else {
    $config
}
