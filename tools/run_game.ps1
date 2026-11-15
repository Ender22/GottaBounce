# Launch the game windowed (rendered) so gbplay.py can drive it.
# Usage: powershell -File tools/run_game.ps1 [scene] [-Port 9101] [-KillAll] [-Wait] [-Resolution 1920x1080] [-Position 0,0]
#
# WK-130 - parallel agents: each agent picks its OWN port (e.g. 9100 + agent slot) and passes it everywhere:
#   powershell -File tools/run_game.ps1 -Port 9101
#   python tools/gbplay.py --port 9101 screenshot tools/out/x.png
#   powershell -File tools/stop_game.ps1 -Port 9101
# -Port N   : the game's automation server listens on 127.0.0.1:N (always passes "-- --gb-port=N"; WK-38: a game
#             launched WITHOUT it runs no server). Default: env GB_PORT if set, else 9090. -Port 0 = no server.
# -KillAll  : OLD behaviour - force-kill EVERY Godot process first (other agents' games too). Off by default.
# Without -KillAll nothing is killed; if something already listens on the port, the script refuses to launch.
param(
    [string]$Scene = "",
    [switch]$Wait,
    [string]$Resolution = "1280x720",
    [string]$Position = "50,50",
    [int]$Port = -1,
    [switch]$KillAll
)
$godot = "C:\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe"
$proj = Split-Path $PSScriptRoot -Parent

if ($Port -lt 0) {
    $Port = 9090
    if ($env:GB_PORT) {
        $parsed = 0
        if ([int]::TryParse($env:GB_PORT.Trim(), [ref]$parsed) -and $parsed -ge 0 -and $parsed -le 65535) { $Port = $parsed }
        else { Write-Output "WARNING: ignoring invalid GB_PORT='$($env:GB_PORT)', using 9090" }
    }
}

# PID listening on 127.0.0.1:<p>, or 0. Uses netstat (no TCP connect - connecting to a game's server
# would kick whatever client is driving it).
function Get-ListenerPid([int]$p) {
    foreach ($line in (netstat -ano -p TCP)) {
        $f = ($line.Trim() -split '\s+')
        if ($f.Count -ge 5 -and $f[3] -eq 'LISTENING' -and $f[1] -match (':' + $p + '$')) { return [int]$f[4] }
    }
    return 0
}

if ($KillAll) {
    # Old behaviour: kill every Godot (zombies hog CPU and hold ports). Kills OTHER agents' games too.
    Get-Process | Where-Object { $_.ProcessName -like 'Godot*' } | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 300
}

if ($Port -gt 0) {
    $holder = Get-ListenerPid $Port
    if ($holder -ne 0) {
        $hp = Get-Process -Id $holder -ErrorAction SilentlyContinue
        $hn = if ($hp) { $hp.ProcessName } else { "?" }
        Write-Output "ABORT: port $Port is already in use by PID $holder ($hn). Pick another -Port (e.g. 9100 + your agent slot),"
        Write-Output "       or stop your own game with: powershell -File tools/stop_game.ps1 -Port $Port"
        exit 2
    }
}

$logName = if ($Port -eq 9090) { "gottabounce_run.log" } else { "gottabounce_run_$Port.log" }
$logPath = Join-Path $env:TEMP $logName
$argList = @("--path", "`"$proj`"", "--resolution", $Resolution, "--position", $Position)
if ($Scene -ne "") { $argList += $Scene }
# WK-38: ALWAYS pass the port. The game's automation server is OFF unless --gb-port / GB_PORT opt in (so the
# owner's PLAY GOTTABOUNCE.bat and exported builds never listen on a TCP port); this script is the opt-in.
$argList += @("--", "--gb-port=$Port")

$proc = Start-Process -FilePath $godot -ArgumentList $argList -PassThru `
    -RedirectStandardOutput $logPath -RedirectStandardError "$logPath.err"
Write-Output "Started PID $($proc.Id) (port $Port); log: $logPath"

# WK-100: display-off pre-flight (runs while Godot boots, so it adds no wait). Warning only.
$displayCheck = Join-Path $PSScriptRoot "display_check.ps1"
if (Test-Path $displayCheck) { try { & $displayCheck } catch { } ; $global:LASTEXITCODE = 0 }

if ($Port -eq 0) {
    Write-Output "Interaction server disabled (-Port 0) - gbplay cannot drive this instance."
} else {
    # Wait for the TCP server to come up (max 20s)
    $deadline = (Get-Date).AddSeconds(20)
    $listener = 0
    while ((Get-Date) -lt $deadline) {
        $listener = Get-ListenerPid $Port
        if ($listener -ne 0) { break }
        if ($proc.HasExited) { break }
        Start-Sleep -Milliseconds 500
    }
    if ($listener -ne 0) {
        # The _console.exe launcher spawns the real Godot exe as a child; the child owns the socket.
        $ours = ($listener -eq $proc.Id)
        if (-not $ours) {
            $lp = Get-CimInstance Win32_Process -Filter "ProcessId=$listener" -ErrorAction SilentlyContinue
            if ($lp -and $lp.ParentProcessId -eq $proc.Id) { $ours = $true }
        }
        if ($ours) { Write-Output "Interaction server UP on $Port (game PID $listener, launcher PID $($proc.Id))" }
        else { Write-Output "WARNING: port $Port is held by PID $listener, which is NOT the game just launched (PID $($proc.Id))" }
    }
    else { Write-Output "WARNING: server not reachable on $Port after 20s - check $logPath" }
}
if ($Wait) { Wait-Process -Id $proc.Id }
