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
        [Object]$Policy
    )

    $Policy | Export-CliXml $env:LockdownPolicyPath
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
        $script:policy."$SettingName" = $NewValue
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
    $script:policy."$SettingName" = $NewValue
    if (-not (Test-Path $NewValue)) {
        Write-Warning "Could not find path `"$NewValue`", but applying the setting anyway."
    }
}


function Test-UserIsAdmin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")
}


$policy = Get-LockdownPolicy
$policy.Unapplied = $true
if ($DeviceWhitelistPath) {
    Change-PathPolicy -SettingName "DeviceWhitelistPath" -OriginalValue $policy.DeviceWhitelistPath -NewValue $DeviceWhitelistPath
}
if ($LogPath) {
    Change-PathPolicy -SettingName "LogPath" -OriginalValue $policy.LogPath -NewValue $LogPath
}
if ($LogLevel) {
    Change-BooleanPolicy -SettingName "LogLevel" -OriginalValue $policy.LogLevel -NewValue $LogLevel -Options "MESSAGE","VERBOSE"
}
if ($StatusFilePath) {
    Change-PathPolicy -SettingName "StatusFilePath" -OriginalValue $policy.StatusFilePath -NewValue $StatusFilePath
}
if ($AlertFilePath) {
    Change-PathPolicy -SettingName "AlertFilePath" -OriginalValue $policy.AlertFilePath -NewValue $AlertFilePath
}
if ($LockOnNewDevice) {
    Change-BooleanPolicy -SettingName "LockOnNewDevice" -OriginalValue $policy.LockOnNewDevice -NewValue $LockOnNewDevice
}
if ($DisableNewDevice) {
    Change-BooleanPolicy -SettingName "DisableNewDevice" -OriginalValue $policy.DisableNewDevice -NewValue $DisableNewDevice
}
if ($DisableUSBStorage) {
    Change-BooleanPolicy -SettingName "DisableUSBStorage" -OriginalValue $policy.DisableUSBStorage -NewValue $DisableUSBStorage
}
if ($AuditCredentialEvents) {
    Change-BooleanPolicy -SettingName "AuditCredentialEvents" -OriginalValue $policy.AuditCredentialEvents -NewValue $AuditCredentialEvents
}
if ($AlertOnCredentialEvents) {
    Change-BooleanPolicy -SettingName "AlertOnCredentialEvents" -OriginalValue $policy.AlertOnCredentialEvents -NewValue $AlertOnCredentialEvents
}
if ($CredentialEventAuditLogPath) {
    Change-PathPolicy -SettingName "CredentialEventAuditLogPath" -OriginalValue $policy.CredentialEventAuditLogPath -NewValue $CredentialEventAuditLogPath
}
if ($CredentialEventWhitelistPath) {
    Change-PathPolicy -SettingName "CredentialEventWhitelistPath" -OriginalValue $policy.CredentialEventWhitelistPath -NewValue $CredentialEventWhitelistPath
}
if ($LockdownEnabled) {
    Change-BooleanPolicy -SettingName "LockdownEnabled" -OriginalValue $policy.LockdownEnabled -NewValue $LockdownEnabled
}
if ($Unapplied) {
    Change-BooleanPolicy -SettingName "Unapplied" -OriginalValue $policy.Unapplied -NewValue $Unapplied
}
if ($Default) {
    Lockdown -Log "Restoring default policy"
    $policy = Get-LockdownPolicy -Default
    $policy
}


if (-not (Test-UserIsAdmin)) {
    Write-Warning "The lockdown policy can only be set by an administrator."
    return
} else {
    Save-NewPolicy $policy
    if (-not $NoReload) {
        $policy.Unapplied = $false
        Save-NewPolicy $policy
        Lockdown -Reload
    }
}
