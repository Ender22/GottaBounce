# WK-100: display-off pre-flight for run_game.ps1 / record_match.ps1 (and anyone else).
# When the laptop screen sleeps, Windows Modern Standby throttles a windowed Godot to ~30 Hz with
# ~500 ms present() stalls (then may freeze it). Every perf / timing / feel number taken then is bogus
# (docs/WEEKEND_LESSONS.md "DISPLAY OFF = BOGUS PERF DATA", docs/audit/2026-11-14_perf_wk91.md).
#
# Signals (both cheap, ~0.3 s total):
#   1. the latest Kernel-Power 506/507 event in the System log: 506 = entered Modern Standby,
#      507 = exited. If the newest one is 506 the display is (still) off.
#   2. WMI WmiMonitorBasicDisplayParams.Active: if no monitor reports Active, the display is off.
# Never blocks and never throws: prints ONE line and returns nothing. Exit code 1 = display looks off
# (only visible via $LASTEXITCODE; callers do not have to check it).
#
# Test hook: $env:GB_DISPLAY_STUB = "off" (or "506") forces the warning, "on" (or "507") forces OK.
# Usage: powershell -File tools/display_check.ps1     (ASCII-only file - keep it that way)
param([switch]$Quiet)

$off = $false
$why = @()
try {
    $stub = "$env:GB_DISPLAY_STUB".Trim().ToLower()
    if ($stub -ne "") {
        if ($stub -eq "off" -or $stub -eq "506") {
            $off = $true
            $why += "stubbed by GB_DISPLAY_STUB=$stub"
        }
    } else {
        try {
            $ev = Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-Kernel-Power'; Id = 506, 507 } `
                -MaxEvents 1 -ErrorAction Stop
            if ($ev -and $ev.Id -eq 506) {
                $off = $true
                $why += ("Kernel-Power 506 (entered Modern Standby) at {0}, no 507 wake since" -f $ev.TimeCreated.ToString("HH:mm:ss"))
            }
        } catch { }   # no events / log unreadable: fall through to the WMI signal
        try {
            $mons = @(Get-CimInstance -Namespace root/wmi -ClassName WmiMonitorBasicDisplayParams `
                -OperationTimeoutSec 3 -ErrorAction Stop)
            if ($mons.Count -gt 0 -and -not ($mons | Where-Object { $_.Active })) {
                $off = $true
                $why += "WMI reports no active monitor"
            }
        } catch { }
    }
} catch {
    if (-not $Quiet) { Write-Output "Display check: skipped ($($_.Exception.Message))" }
    exit 0
}

if ($off) {
    Write-Output ("WARNING: DISPLAY OFF - timings invalid. " + ($why -join "; ") + ".")
    Write-Output "         Windows throttles the game to ~30 Hz with ~500 ms stalls: wake the screen before trusting any fps / timing / feel number."
    exit 1
}
if (-not $Quiet) { Write-Output "Display check: screen awake (perf/timing numbers valid)." }
exit 0
