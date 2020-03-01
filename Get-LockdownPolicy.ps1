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

    [Switch]$CredentialEventBackoffTimeout,

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
        CredentialEventBackoffTimeout = 60
        LockdownEnabled = $true
        Unapplied = $false
    }
}


function Get-SavedPolicy {
    if (($env:LockdownPolicyPath -ne $null) -and (Test-Path $env:LockdownPolicyPath)) {
        $policy = Import-CliXml $env:LockdownPolicyPath
    }
    if (-not $policy -or $policy.GetType().Name -ne "PSCustomObject") {
        Write-Warning "No valid policy found at `"$env:LockdownPolicyPath`" -- Loading default policy"
        $policy = Get-DefaultPolicy
    }
    $policy
}


$policy = Get-SavedPolicy
if ($Default) {
    $policy = Get-DefaultPolicy
}
if ($DeviceWhitelistPath) {
    $policy.DeviceWhitelistPath
} elseif ($LogPath) {
    $policy.LogPath
} elseif ($LogLevel) {
    $policy.LogLevel
} elseif ($StatusFilePath) {
    $policy.StatusFilePath
} elseif ($AlertFilePath) {
    $policy.AlertFilePath
} elseif ($LockOnNewDevice) {
    $policy.LockOnNewDevice
} elseif ($DisableNewDevice) {
    $policy.DisableNewDevice
} elseif ($DisableUSBStorage) {
    $policy.DisableUSBStorage
} elseif ($AuditCredentialEvents) {
    $policy.AuditCredentialEvents
} elseif ($AlertOnCredentialEvents) {
    $policy.AlertOnCredentialEvents
} elseif ($CredentialEventAuditLogPath) {
    $policy.CredentialEventAuditLogPath
} elseif ($CredentialEventWhitelistPath) {
    $policy.CredentialEventWhitelistPath
} elseif ($CredentialEventBackoffTimeout) {
    $policy.CredentialEventBackoffTimeout
} elseif ($LockdownEnabled) {
    $policy.LockdownEnabled
} elseif ($Unapplied) {
    $policy.Unapplied
} else {
    $policy
}
