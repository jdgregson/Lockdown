# Lockdown is a system hardening tool which applies, enforces, and reports on
# various system hardening settings according to a "lockdown policy". For
# example, it can lock the system when various USB devices are inserted, and
# send alerts when backups are out of date or pre-defined anti-virus settings
# and components are disabled.
#
# This file provides a curses-like GUI in PowerShell which allows for policy
# management, log review, and monitoring of various system services.
#
# Copyright (C) jdgregson, 2019
# Author: Jonathan Gregson <jonathan@jdgregson.com>

Import-Module psui1 -Force -DisableNameChecking
$LogWindowStart = 54


function ColorMatch {
    #https://stackoverflow.com/questions/12609760
    Param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string] $InputObject,
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $Pattern,
        [Parameter(Mandatory = $false, Position = 1)]
        [string] $Color = 'Red'
    )

    begin {$r = [regex]$Pattern}
    process {
        $ms = $r.matches($InputObject)
        $startIndex = 0
        foreach ($m in $ms) {
            $nonMatchLength = $m.Index - $startIndex
            Write-Host $InputObject.Substring($startIndex, $nonMatchLength) -NoNew
            Write-Host $m.Value -Fore $Color -NoNew
            $startIndex = $m.Index + $m.Length
        }
        if ($startIndex -lt $InputObject.Length) {
            Write-Host $InputObject.Substring($startIndex) -NoNew
        }
        Write-Host
    }
}


function Test-ProcessRunning {
    Param (
        [string]$Process
    )

    $proc = try {Get-Process $Process *>&1} catch {$_}
    if (("Process", "Object[]") -contains $proc.GetType().Name) {
        return $True
    } else {
        return $False
    }
}


function Test-UserIsAdmin {
    return ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')
}


function Get-LogLines {
    $LogWidth = ((Get-UIConsoleWidth) - ($LogWindowStart + 4))
    $LocalLogContents = (Get-Content $config.LogPath -Tail ((Get-UIConsoleHeight) - 2))
    $Output = @()
    for ($i = 0; $i -lt $LocalLogContents.Count; $i++) {
        $line = $LocalLogContents[$i]
        $j = 1
        for ($k = 0; $k -le $line.length; $k += $LogWidth) {
            $Output += $line[$k..(($LogWidth * $j) - 1)] -join ""
            $j++
        }
    }
    return $Output
}


function Draw-ToggleSwitch {
    Param (
        [string]$Value1 = "On",
        [string]$Value2 = "Off",
        [string]$Selected = 1,
        [int]$ItemWidth = 11
    )

    if ($Value1.Length -lt $ItemWidth) {
        for ($i = 1; $Value1.Length -lt $ItemWidth; $i++) {
            $Value1 = if ($i % 2 -eq 0) {" $Value1"} else {"$Value1 "}
        }
    }
    if ($Value2.Length -lt $ItemWidth) {
        for ($i = 1; $Value2.Length -lt $ItemWidth; $i++) {
            $Value2 = if ($i % 2 -eq 0) {" $Value2"} else {"$Value2 "}
        }
    }
    if ($Selected -eq 1) {
        Write-UIColoredText " $Value1 " -BackgroundColor Green -ForegroundColor Black
        Write-UIColoredText " $Value2|"
    } else {
        Write-UIColoredText "|$Value1 "
        Write-UIColoredText " $Value2 " -BackgroundColor DarkRed -ForegroundColor Black
    }
}


function Draw-LockdownControls {
    Param (
        [object]$Controls,
        [int]$SelectedControl
    )

    $NextLine = 0
    $longestControl = 0
    for ($i = 0; $i -lt $Controls.Count; $i++) {
        if ($Controls[$i][0].Length -gt $longestControl) {
            $longestControl = $Controls[$i][0].Length
        }
    }

    for ($i = 0; $i -lt $Controls.Count; $i++) {
        Set-UICursorPosition -X 2 -Y (2 * ($i+1))
        if ($script:UnappliedChanges -eq $True) {
            $title = "Unapplied changes!"
        } else {
            $title = " "    
        }
        if ($Controls[$i][0] -eq "#APPLY") {
            if ($SelectedControl -eq $i) {
                Write-UIText "> $title$(" " * ($longestControl + 2 - $title.Length))"
                Write-UIColoredText "$(" "*11)APPLY$(" "*10)" -BackgroundColor DarkRed -ForegroundColor Black
            } else {
                Write-UIText "  $title$(" " * ($longestControl + 2 - $title.Length))"
                Write-UIColoredText "$(" "*11)APPLY$(" "*10)" -BackgroundColor DarkGray -ForegroundColor Black
            }
        } else {
            $leadchar = " "
            if ($SelectedControl -eq $i) {
                $leadchar = ">"
            }
            $linetext = "$leadchar $($Controls[$i][0]): "
            Write-UIText ($linetext + (" " * ($longestControl - ($linetext.Length - 4))))
            if ($Controls[$i][1] -eq $Controls[$i][2]) {
                Draw-ToggleSwitch $Controls[$i][2] $Controls[$i][3]
            } else {
                Draw-ToggleSwitch $Controls[$i][2] $Controls[$i][3] -Selected 2
            }
        }
    }
}


function Draw-LockdownMonitors {
    Param (
        [object]$Monitors
    )

    $LineY = 16
    Set-UICursorPosition -X 1 -Y ($LineY-2)
    Write-UITextInverted "  Monitors"
    Write-UIBorder -StartX 11 -StartY ($LineY-2) -Width ($LogWindowStart - 10)

    for ($i = 0; $i -lt $Monitors.Count; $i++) {
        $Section = $Monitors[$i]
        Set-UICursorPosition -X 4 -Y ($LineY++)
        Write-UIText "$($Section[0]) $("_" * ($LogWindowStart - ($Section[0].Length + 8)))"
        for ($j = 0; $j -lt $Section[1].Count; $j++) {
            $Item = $Section[1][$J]
            Set-UICursorPosition -X 4 -Y ($LineY++)
            Write-UIText "  $($Item[0])"
            $TestResult = try {Invoke-Expression "$($Item[1])" *>&1} catch {$_}
            if ($TestResult -eq $Item[2][0]) {
                Write-UIText (" " * (($LogWindowStart - 9) - (($Item[0].Length) + ($Item[2][1].Length))))
                Write-UIColoredText $Item[2][1] -ForegroundColor "Green"
            } elseif ($TestResult -eq $Item[3][0]) {
                Write-UIText (" " * (($LogWindowStart - 9) - (($Item[0].Length) + ($Item[3][1].Length))))
                Write-UIColoredText $Item[3][1] -ForegroundColor "DarkRed"
            } else {
                Write-UIText (" " * (($LogWindowStart - 9) - (($Item[0].Length) + 3)))
                Write-UIText "???"
            }
        }
    }
}


function Draw-LockdownLog {
    Param (
        [object]$LocalLogContents,
        [switch]$Erase
    )

    Set-UICursorPosition -X ($LogWindowStart + 2) -Y 1
    if($Erase) {
        $Height = ((Get-UIConsoleHeight) - 1)
        $LogWidth = ((Get-UIConsoleWidth) - ($LogWindowStart + 4))
        for ($i = 0; $i -lt $Height; $i++) {
            Write-UIText (" " * $LogWidth)
            Set-UICursorPosition -X ($LogWindowStart + 2) -Y (1 + $i)
        }
        Set-UICursorPosition -X ($LogWindowStart + 2) -Y 1
    }
    if ($LocalLogContents) {
        if ($LocalLogContents.Count -gt ((Get-UIConsoleHeight) - 2)) {
            $LocalLogContents = $LocalLogContents[-$((Get-UIConsoleHeight) - 2)..-1]
        }
        for ($i = 0; $i -lt $LocalLogContents.Count; $i++) {
            $LogLine = $LocalLogContents[$i]
            if ($LogLine -and $LogLine -ne "") {
                $LogLine | ColorMatch "\[[0-9/ :]*\]" -Color DarkCyan
            }
            Set-UICursorPosition -X ($LogWindowStart + 2) -Y ($i + 2)
        }
    }
}


function Draw-MainUI {
    Clear
    Write-UITitleLine "Lockdown UI $(' ' * 43) Lockdown Log"
    if (Test-UserIsAdmin) {
        Set-UICursorPosition -X 16 -Y 0
        Write-Host " ADMIN MODE " -BackgroundColor "DarkRed" -ForegroundColor "Black" -NoNewline
    }
    Write-UIBorder -StartY 1 -Height (Get-UIConsoleHeight - 4)
    Write-UIBorder -StartY 1 -StartX $LogWindowStart -Height (Get-UIConsoleHeight - 4)
    Write-UIBorder -StartY 1 -StartX (Get-UIConsoleWidth) -Height (Get-UIConsoleHeight - 4)
    Write-UIBorder -StartY (Get-UIConsoleHeight - 3) -Width (Get-UIConsoleWidth)
    Draw-LockdownControls $Controls $SelectedControl
    Draw-LockdownMonitors $Monitors
    Draw-LockdownLog $LogContents

    Set-UICursorPosition -X 0 -Y (Get-UIConsoleHeight)
    Write-UITitleLine "A: Admin mode   UP/K: Up   DOWN/J: Down   Space/Enter: Toggle   R: Refresh   Q: Quit"
    Set-UICursorPosition -X 0 -Y 0
}


function Toggle-Control {
    Param (
        [object]$Controls,
        [int]$SelectedControl
    )

    if (-not(Test-UserIsAdmin)) {
        $message = "You must be an administrator to change the Lockdown policy. " +
            "Press `"A`" to elevate this session."
        Write-UIError -Title "Elevation required" -Message $message
        Clear-Host
        Draw-MainUI
        return
    }

    $script:UnappliedChanges = $True
    if ($Controls[$SelectedControl][0] -eq "#APPLY") {
        $policy = (Get-LockdownPolicy)
        Write-UIMessage "Applying new Lockdown policy: $policy" "Applying Lockdown Policy" -WaitForInput $False
        $script:UnappliedChanges = $False
        Lockdown -Reload
        Draw-MainUI
    } else {
        $active = $Controls[$SelectedControl][1]
        if ($active -eq $Controls[$SelectedControl][2]) {
            $SelectedOption = $Controls[$SelectedControl][3]
        } elseif ($active -eq $Controls[$SelectedControl][3]) {
            $SelectedOption = $Controls[$SelectedControl][2]
        }
        Invoke-Expression "Set-LockdownPolicy -$($Controls[$SelectedControl][4]) $SelectedOption -NoReload"
    }
}


function Get-LockdownControls {
    return @(
        @("Lockdown Status", $config.Status, "ENABLED", "DISABLED", "Status"),
        @("USB Storage", $config.USBStorage, "BLOCKED", "UNBLOCKED", "USBStorage"),
        @("Lock On New Device", $config.LockOnNewDevice, "TRUE", "FALSE", "LockOnNewDevice"),
        @("Disable New Devices", $config.DisableNewDevice, "TRUE", "FALSE", "DisableNewDevice"),
        @("#APPLY")
    )
}


function Get-LockdownMonitors {
    return @(
        @("Lockdown", @(
            @("lockdown pulse", "Lockdown -pulse", @("Alive", "ALIVE"), @("Dead", "DEAD")),
            @("unapplied changes", "Get-LockdownPolicy -Unapplied", @($False, "FALSE"), @($True, "TRUE"))
        )),
        @("Malwarebytes", @(
            @("MBAMService.exe", "Test-ProcessRunning 'MBAMService'", @($True, "RUNNING"), @($False, "NOT RUNNING")),
            @("mbamtray.exe", "Test-ProcessRunning 'mbamtray'", @($True, "RUNNING"), @($False, "NOT RUNNING"))
        )),
        @("BitDefender", @(
            @("vsserv.exe", "Test-ProcessRunning 'vsserv'", @($True, "RUNNING"), @($False, "NOT RUNNING")),
            @("bdagent.exe", "Test-ProcessRunning 'bdagent'", @($True, "RUNNING"), @($False, "NOT RUNNING")),
            @("bdservicehost.exe", "Test-ProcessRunning 'bdservicehost'", @($True, "RUNNING"), @($False, "NOT RUNNING"))
        )),
        @("CrashPlanPro", @(
            @("CrashPlanDesktop.exe", "Test-ProcessRunning 'CrashPlanDesktop'", @($True, "RUNNING"), @($False, "NOT RUNNING")),
            @("CrashPlanService.exe", "Test-ProcessRunning 'CrashPlanService'", @($True, "RUNNING"), @($False, "NOT RUNNING"))
        )),
        @("NetLimiter", @(
            @("NLClientApp.exe", "Test-ProcessRunning 'NLClientApp'", @($True, "RUNNING"), @($False, "NOT RUNNING")),
            @("NLSvc.exe", "Test-ProcessRunning 'NLSvc'", @($True, "RUNNING"), @($False, "NOT RUNNING"))
        )),
        @("Misc", @(
            @("0PatchServicex64.exe", "Test-ProcessRunning '0PatchServicex64'", @($True, "RUNNING"), @($False, "NOT RUNNING")),
            @("googledrivesync.exe", "Test-ProcessRunning 'googledrivesync'", @($True, "RUNNING"), @($False, "NOT RUNNING")),
            @("OneDrive.exe", "Test-ProcessRunning 'OneDrive'", @($True, "RUNNING"), @($False, "NOT RUNNING"))
        ))
    )
}


$config = Get-LockdownPolicy
$SelectedControl = 0
$Controls = Get-LockdownControls
$Monitors = Get-LockdownMonitors
$LogContents = Get-LogLines
$UnappliedChanges = $False
if ((Get-LockdownPolicy -Unapplied) -eq "TRUE") {$UnappliedChanges = $True}
Draw-MainUI
while ($True) {
    $InputChar = [System.Console]::ReadKey($true)
    if($InputChar.Key -eq [System.ConsoleKey]::DownArrow -or $InputChar.Key -eq [System.ConsoleKey]::Tab -or $InputChar.Key -eq "J") {
        $SelectedControl += 1
        if ($SelectedControl -ge $Controls.Count) {
            $SelectedControl = 0
        }
        Draw-LockdownControls $Controls $SelectedControl
    } elseif($InputChar.Key -eq [System.ConsoleKey]::UpArrow -or $InputChar.Key -eq "K") {
        $SelectedControl -= 1
        if ($SelectedControl -lt 0) {
            $SelectedControl = ($Controls.Count - 1)
        }
        Draw-LockdownControls $Controls $SelectedControl
    } elseif($InputChar.Key -eq "A") {
        if (-not(Test-UserIsAdmin)) {
            if ([int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000) {
                $CommandLine = "-File `"" + $MyInvocation.MyCommand.Path + "`" " + $MyInvocation.UnboundArguments
                Start-Process -FilePath PowerShell.exe -Verb Runas -ArgumentList $CommandLine
                Exit
            }
        }
    } elseif($InputChar.Key -eq [System.ConsoleKey]::SpaceBar -or $InputChar.Key -eq [System.ConsoleKey]::Enter) {
        Toggle-Control $Controls $SelectedControl
        $config = Get-LockdownPolicy
        $Controls = Get-LockdownControls
        Draw-LockdownControls $Controls $SelectedControl
    } elseif($InputChar.Key -eq [System.ConsoleKey]::Escape -or $InputChar.Key -eq "q") {
        Clear
        Exit
    } elseif($InputChar.Key -eq [System.ConsoleKey]::R) {
        Clear
        Draw-MainUI
    }
    $NewLogContents = Get-LogLines
    if (Compare-Object $NewLogContents $LogContents) {
        $LogContents = $NewLogContents
        Draw-LockdownLog $LogContents -Erase
    }
    Set-UICursorPosition -X 0 -Y (Get-UIConsoleHeight)
}
