# File: LockdownUI.ps1
# Project: Lockdown, https://github.com/jdgregson/Lockdown
# Copyright (C) Jonathan Gregson, 2020
# Author: Jonathan Gregson <jonathan@jdgregson.com>

Import-Module psui1 -Force -DisableNameChecking
$logWindowStart = 51


function ColorMatch {
    #https://stackoverflow.com/questions/12609760
    Param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [String]$InputObject,

        [Parameter(
            Mandatory = $true,
            Position = 0
        )]
        [String]$Pattern,

        [Parameter(
            Mandatory = $false,
            Position = 1
        )]
        [String]$Color = "Red"
    )

    begin {
        $r = [regex]$Pattern
    }
    process {
        $ms = $r.matches($InputObject)
        $startIndex = 0
        foreach ($m in $ms) {
            $nonMatchLength = $m.Index - $startIndex
            Write-Host $InputObject.Substring($startIndex, $nonMatchLength) -NoNewline
            Write-Host $m.Value -ForegroundColor $Color -NoNewline
            $startIndex = $m.Index + $m.Length
        }
        if ($startIndex -lt $InputObject.Length) {
            Write-Host $InputObject.Substring($startIndex) -NoNewline
        }
        Write-Host
    }
}


function Test-ProcessRunning {
    Param (
        [String]$ProcessName
    )

    $process = Get-Process $ProcessName -ErrorAction SilentlyContinue
    if ($process) {
        $true
    } else {
        $false
    }
}


function Test-UserIsAdmin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")
}


function Get-LogLines {
    $logWidth = ((Get-UIConsoleWidth) - ($logWindowStart + 4))
    $localLogContents = (Get-Content $policy.LogPath -Tail ((Get-UIConsoleHeight) - 2))
    $output = @()
    for ($i = 0; $i -lt $localLogContents.Count; $i++) {
        $line = $localLogContents[$i]
        $j = 1
        for ($k = 0; $k -le $line.length; $k += $logWidth) {
            $output += $line[$k..(($logWidth * $j) - 1)] -join ""
            $j++
        }
    }
    $output
}


function Draw-ToggleSwitch {
    Param (
        [String]$Value1 = "On",

        [String]$Value2 = "Off",

        [String]$Selected = 1,

        [Int]$ItemWidth = 6
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
        [Object]$controls,

        [Int]$selectedControl
    )

    $longestControl = 0
    for ($i = 0; $i -lt $controls.Count; $i++) {
        if ($controls[$i][0].Length -gt $longestControl) {
            $longestControl = $controls[$i][0].Length
        }
    }

    for ($i = 0; $i -lt $controls.Count; $i++) {
        Set-UICursorPosition -X 2 -Y (2 * ($i+1))
        if ($script:UnappliedChanges -eq $true) {
            $title = "Unapplied changes!"
        } else {
            $title = " "
        }
        if ($controls[$i][0] -eq "#APPLY") {
            if ($selectedControl -eq $i) {
                Write-UIText "> $title$(" " * ($longestControl + 2 - $title.Length))"
                Write-UIColoredText "$(" "*5)APPLY$(" "*6)" -BackgroundColor DarkRed -ForegroundColor Black
            } else {
                Write-UIText "  $title$(" " * ($longestControl + 2 - $title.Length))"
                Write-UIColoredText "$(" "*5)APPLY$(" "*6)" -BackgroundColor DarkGray -ForegroundColor Black
            }
        } else {
            $leadChar = " "
            if ($selectedControl -eq $i) {
                $leadChar = ">"
            }
            $lineText = "$leadChar $($controls[$i][0]): "
            Write-UIText ($lineText + (" " * ($longestControl - ($lineText.Length - 4))))
            $leftText = $controls[$i][2]
            $rightText = $controls[$i][3]
            if ($leftText -eq $true) {$leftText = "ON"}
            if ($leftText -eq $false) {$leftText = "OFF"}
            if ($rightText -eq $true) {$rightText = "ON"}
            if ($rightText -eq $false) {$rightText = "OFF"}
            if ($controls[$i][1] -eq $controls[$i][2]) {
                Draw-ToggleSwitch $leftText $rightText
            } else {
                Draw-ToggleSwitch $leftText $rightText -Selected 2
            }
        }
    }
}


function Draw-LockdownMonitors {
    Param (
        [Object]$monitors
    )

    $lineY = 16
    Set-UICursorPosition -X 1 -Y ($lineY-2)
    Write-UITextInverted "  Monitors"
    Write-UIBorder -StartX 11 -StartY ($lineY-2) -Width ($logWindowStart - 10)

    for ($i = 0; $i -lt $monitors.Count; $i++) {
        $section = $monitors[$i]
        Set-UICursorPosition -X 4 -Y ($lineY++)
        Write-UIText "$($section[0]) $("_" * ($logWindowStart - ($section[0].Length + 8)))"
        for ($j = 0; $j -lt $section[1].Count; $j++) {
            $item = $section[1][$j]
            Set-UICursorPosition -X 4 -Y ($lineY++)
            Write-UIText "  $($item[0])"
            $testResult = try {Invoke-Expression "$($item[1])" *>&1} catch {$_}
            if ($testResult -eq $item[2][0]) {
                Write-UIText (" " * (($logWindowStart - 9) - (($item[0].Length) + ($item[2][1].Length))))
                Write-UIColoredText $item[2][1] -ForegroundColor "Green"
            } elseif ($testResult -eq $item[3][0]) {
                Write-UIText (" " * (($logWindowStart - 9) - (($item[0].Length) + ($item[3][1].Length))))
                Write-UIColoredText $item[3][1] -ForegroundColor "DarkRed"
            } else {
                Write-UIText (" " * (($logWindowStart - 9) - (($item[0].Length) + 3)))
                Write-UIText "???"
            }
        }
    }
}


function Draw-LockdownLog {
    Param (
        [Object]$LocalLogContents,

        [Switch]$Erase
    )

    Set-UICursorPosition -X ($logWindowStart + 2) -Y 1
    if ($Erase) {
        $height = ((Get-UIConsoleHeight) - 1)
        $logWidth = ((Get-UIConsoleWidth) - ($logWindowStart + 4))
        for ($i = 0; $i -lt $height; $i++) {
            Write-UIText (" " * $logWidth)
            Set-UICursorPosition -X ($logWindowStart + 2) -Y (1 + $i)
        }
        Set-UICursorPosition -X ($logWindowStart + 2) -Y 1
    }
    if ($LocalLogContents) {
        if ($LocalLogContents.Count -gt ((Get-UIConsoleHeight) - 2)) {
            $LocalLogContents = $LocalLogContents[-$((Get-UIConsoleHeight) - 2)..-1]
        }
        for ($i = 0; $i -lt $LocalLogContents.Count; $i++) {
            $logLine = $LocalLogContents[$i]
            if ($logLine -and $logLine -ne "") {
                $logLine | ColorMatch "\[[0-9/ :]*\]" -Color DarkCyan
            }
            Set-UICursorPosition -X ($logWindowStart + 2) -Y ($i + 2)
        }
    }
}


function Draw-MainUI {
    Clear-Host
    Write-UITitleLine "Lockdown UI $(' ' * 43) Lockdown Log"
    if (Test-UserIsAdmin) {
        Set-UICursorPosition -X 16 -Y 0
        Write-Host " ADMIN MODE " -BackgroundColor "DarkRed" -ForegroundColor "Black" -NoNewline
    }
    Write-UIBorder -StartY 1 -Height (Get-UIConsoleHeight - 4)
    Write-UIBorder -StartY 1 -StartX $logWindowStart -Height (Get-UIConsoleHeight - 4)
    Write-UIBorder -StartY 1 -StartX (Get-UIConsoleWidth) -Height (Get-UIConsoleHeight - 4)
    Write-UIBorder -StartY (Get-UIConsoleHeight - 3) -Width (Get-UIConsoleWidth)
    Draw-LockdownControls $controls $selectedControl
    Draw-LockdownMonitors $monitors
    Draw-LockdownLog $logContents

    Set-UICursorPosition -X 0 -Y (Get-UIConsoleHeight)
    Write-UITitleLine "A: Admin mode   UP/K: Up   DOWN/J: Down   Space/Enter: Toggle   R: Refresh   Q: Quit"
    Set-UICursorPosition -X 0 -Y 0
}


function Toggle-Control {
    Param (
        [Object]$controls,

        [Int]$selectedControl
    )

    if (-not (Test-UserIsAdmin)) {
        $message = "You must be an administrator to change the Lockdown policy. Press `"A`" to elevate this session."
        Write-UIError -Title "Elevation required" -Message $message
        Clear-Host
        Draw-MainUI
        return
    }

    $script:UnappliedChanges = $true
    if ($controls[$selectedControl][0] -eq "#APPLY") {
        $policy = Get-LockdownPolicy
        Write-UIMessage "Applying new Lockdown policy: $policy" "Applying Lockdown Policy" -WaitForInput $false
        $script:UnappliedChanges = $false
        Lockdown -Reload
        Draw-MainUI
    } else {
        $active = $controls[$selectedControl][1]
        if ($active -eq $controls[$selectedControl][2]) {
            $selectedOption = $controls[$selectedControl][3]
        } elseif ($active -eq $controls[$selectedControl][3]) {
            $selectedOption = $controls[$selectedControl][2]
        }
        Invoke-Expression "Set-LockdownPolicy -$($controls[$selectedControl][4]) $selectedOption -NoReload"
    }
}


function Get-LockdownControls {
    return @(
        @("Lockdown status", $policy.LockdownEnabled, $true, $false, "LockdownEnabled"),
        @("Disable USB storage", $policy.DisableUSBStorage, $true, $false, "DisableUSBStorage"),
        @("Lock on new devices", $policy.LockOnNewDevice, $true, $false, "LockOnNewDevice"),
        @("Disable new devices", $policy.DisableNewDevice, $true, $false, "DisableNewDevice"),
        @("Alert on credential events", $policy.AlertOnCredentialEvents, $true, $false, "AlertOnCredentialEvents"),
        @("#APPLY")
    )
}


function Get-LockdownMonitors {
    return @(
        @("Lockdown", @(
            @("lockdown pulse", "Lockdown -pulse", @("Alive", "ALIVE"), @("Dead", "DEAD")),
            @("unapplied changes", "Get-LockdownPolicy -Unapplied", @($false, "FALSE"), @($true, "TRUE"))
        )),
        @("Malwarebytes", @(
            @("MBAMService.exe", "Test-ProcessRunning 'MBAMService'", @($true, "RUNNING"), @($false, "NOT RUNNING")),
            @("mbamtray.exe", "Test-ProcessRunning 'mbamtray'", @($true, "RUNNING"), @($false, "NOT RUNNING"))
        )),
        @("BitDefender", @(
            @("vsserv.exe", "Test-ProcessRunning 'vsserv'", @($true, "RUNNING"), @($false, "NOT RUNNING")),
            @("bdagent.exe", "Test-ProcessRunning 'bdagent'", @($true, "RUNNING"), @($false, "NOT RUNNING")),
            @("bdservicehost.exe", "Test-ProcessRunning 'bdservicehost'", @($true, "RUNNING"), @($false, "NOT RUNNING"))
        )),
        @("CrashPlanPro", @(
            @("CrashPlanDesktop.exe", "Test-ProcessRunning 'CrashPlanDesktop'", @($true, "RUNNING"), @($false, "NOT RUNNING")),
            @("CrashPlanService.exe", "Test-ProcessRunning 'CrashPlanService'", @($true, "RUNNING"), @($false, "NOT RUNNING"))
        )),
        @("NetLimiter", @(
            @("NLClientApp.exe", "Test-ProcessRunning 'NLClientApp'", @($true, "RUNNING"), @($false, "NOT RUNNING")),
            @("NLSvc.exe", "Test-ProcessRunning 'NLSvc'", @($true, "RUNNING"), @($false, "NOT RUNNING"))
        )),
        @("Misc", @(
            @("0PatchServicex64.exe", "Test-ProcessRunning '0PatchServicex64'", @($true, "RUNNING"), @($false, "NOT RUNNING")),
            @("googledrivesync.exe", "Test-ProcessRunning 'googledrivesync'", @($true, "RUNNING"), @($false, "NOT RUNNING")),
            @("OneDrive.exe", "Test-ProcessRunning 'OneDrive'", @($true, "RUNNING"), @($false, "NOT RUNNING"))
        ))
    )
}


$policy = Get-LockdownPolicy
$selectedControl = 0
$controls = Get-LockdownControls
$monitors = Get-LockdownMonitors
$logContents = Get-LogLines
$unappliedChanges = $false
if (Get-LockdownPolicy -Unapplied) {
    $unappliedChanges = $true
}
Draw-MainUI
while ($true) {
    $inputChar = [System.Console]::ReadKey($true)
    if ($inputChar.Key -eq [System.ConsoleKey]::DownArrow -or $inputChar.Key -eq [System.ConsoleKey]::Tab -or $inputChar.Key -eq "J") {
        $selectedControl += 1
        if ($selectedControl -ge $controls.Count) {
            $selectedControl = 0
        }
        Draw-LockdownControls $controls $selectedControl
    } elseif ($inputChar.Key -eq [System.ConsoleKey]::UpArrow -or $inputChar.Key -eq "K") {
        $selectedControl -= 1
        if ($selectedControl -lt 0) {
            $selectedControl = ($controls.Count - 1)
        }
        Draw-LockdownControls $controls $selectedControl
    } elseif ($inputChar.Key -eq "A") {
        if (-not (Test-UserIsAdmin)) {
            if ([Int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000) {
                $CommandLine = "-File `"" + $MyInvocation.MyCommand.Path + "`" " + $MyInvocation.UnboundArguments
                Start-Process -FilePath PowerShell.exe -Verb Runas -ArgumentList $CommandLine
                exit
            }
        }
    } elseif ($inputChar.Key -eq [System.ConsoleKey]::SpaceBar -or $inputChar.Key -eq [System.ConsoleKey]::Enter) {
        Toggle-Control $controls $selectedControl
        $policy = Get-LockdownPolicy
        $controls = Get-LockdownControls
        Draw-LockdownControls $controls $selectedControl
    } elseif ($inputChar.Key -eq [System.ConsoleKey]::Escape -or $inputChar.Key -eq "q") {
        Clear-Host
        exit
    } elseif ($inputChar.Key -eq [System.ConsoleKey]::R) {
        Clear-Host
        Draw-MainUI
    }
    $newLogContents = Get-LogLines
    if (Compare-Object $newLogContents $logContents) {
        $logContents = $newLogContents
        Draw-LockdownLog $logContents -Erase
    }
    Set-UICursorPosition -X 0 -Y (Get-UIConsoleHeight)
}
