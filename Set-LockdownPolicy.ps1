# File: Set-LockdownPolicy.ps1
# Project: Lockdown, https://github.com/jdgregson/Lockdown
# Copyright (C) Jonathan Gregson, 2020
# Author: Jonathan Gregson <jonathan@jdgregson.com>

Param (
    [String]$DeviceWhitelistPath,

    [String]$LogPath,

    [String]$StatusFilePath,

    [String]$AlertFilePath,

    [String]$LockOnNewDevice,

    [String]$DisableNewDevice,

    [String]$DisableUSBStorage,

    [String]$AuditCredentialEvents,

    [String]$AlertOnCredentialEvents,

    [String]$CredentialEventAuditLogPath,

    [String]$CredentialEventWhitelistPath,

    [String]$LockdownEnabled,

    [String]$Unapplied,

    [String]$LogLevel,

    [Switch]$NoReload,

    [Switch]$Default
)


function Save-NewPolicy {
    Param (
        [Object]$Config
    )

    $Config | Export-CliXml $env:LockdownConfig
}


function Change-BooleanPolicy {
    Param (
        [String]$SettingName,

        [String]$OriginalValue,

        [String]$NewValue,

        [String[]]$Options = ($true, $false)
    )

    if ($Options -contains $NewValue) {
        Lockdown -Log "Changing $SettingName policy: $OriginalValue -> $NewValue"
        $script:config."$SettingName" = $NewValue
    } else {
        Lockdown -Log "Error changing $SettingName policy: `"$NewValue`" is not a valid option"
        Write-Warning "$SettingName does not support `"$NewValue`" as a policy. Please use: $Options"
    }
}


function Change-PathPolicy {
    Param (
        [String]$SettingName,

        [String]$OriginalValue,

        [String]$NewValue
    )

    Lockdown -Log "Changing $SettingName policy: $OriginalValue -> $NewValue"
    $script:config."$SettingName" = $NewValue
    if (-not (Test-Path $NewValue)) {
        Write-Warning "Could not find path `"$NewValue`", but applying the setting anyway."
    }
}


function Test-UserIsAdmin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")
}


$config = Get-LockdownPolicy
$config.Unapplied = $true
if ($DeviceWhitelistPath) {
    Change-PathPolicy -SettingName "DeviceWhitelistPath" -OriginalValue $config.DeviceWhitelistPath -NewValue $DeviceWhitelistPath
}
if ($LogPath) {
    Change-PathPolicy -SettingName "LogPath" -OriginalValue $config.LogPath -NewValue $LogPath
}
if ($LogLevel) {
    Change-BooleanPolicy -SettingName "LogLevel" -OriginalValue $config.LogLevel -NewValue $LogLevel -Options "MESSAGE","VERBOSE"
}
if ($StatusFilePath) {
    Change-PathPolicy -SettingName "StatusFilePath" -OriginalValue $config.StatusFilePath -NewValue $StatusFilePath
}
if ($AlertFilePath) {
    Change-PathPolicy -SettingName "AlertFilePath" -OriginalValue $config.AlertFilePath -NewValue $AlertFilePath
}
if ($LockOnNewDevice) {
    Change-BooleanPolicy -SettingName "LockOnNewDevice" -OriginalValue $config.LockOnNewDevice -NewValue $LockOnNewDevice
}
if ($DisableNewDevice) {
    Change-BooleanPolicy -SettingName "DisableNewDevice" -OriginalValue $config.DisableNewDevice -NewValue $DisableNewDevice
}
if ($DisableUSBStorage) {
    Change-BooleanPolicy -SettingName "DisableUSBStorage" -OriginalValue $config.DisableUSBStorage -NewValue $DisableUSBStorage
}
if ($AuditCredentialEvents) {
    Change-BooleanPolicy -SettingName "AuditCredentialEvents" -OriginalValue $config.AuditCredentialEvents -NewValue $AuditCredentialEvents
}
if ($AlertOnCredentialEvents) {
    Change-BooleanPolicy -SettingName "AlertOnCredentialEvents" -OriginalValue $config.AlertOnCredentialEvents -NewValue $AlertOnCredentialEvents
}
if ($CredentialEventAuditLogPath) {
    Change-PathPolicy -SettingName "CredentialEventAuditLogPath" -OriginalValue $config.CredentialEventAuditLogPath -NewValue $CredentialEventAuditLogPath
}
if ($CredentialEventWhitelistPath) {
    Change-PathPolicy -SettingName "CredentialEventWhitelistPath" -OriginalValue $config.CredentialEventWhitelistPath -NewValue $CredentialEventWhitelistPath
}
if ($LockdownEnabled) {
    Change-BooleanPolicy -SettingName "LockdownEnabled" -OriginalValue $config.LockdownEnabled -NewValue $LockdownEnabled
}
if ($Unapplied) {
    Change-BooleanPolicy -SettingName "Unapplied" -OriginalValue $config.Unapplied -NewValue $Unapplied
}
if ($Default) {
    Lockdown -Log "Restoring default policy"
    $config = Get-LockdownPolicy -Default
    $config
}


if (-not (Test-UserIsAdmin)) {
    Write-Warning "The lockdown policy can only be set by an administrator."
    return
} else {
    Save-NewPolicy $config
    if (-not $NoReload) {
        $config.Unapplied = $false
        Save-NewPolicy $config
        Lockdown -Reload
    }
}
