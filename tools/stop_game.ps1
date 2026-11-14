# Stop Godot instances.
#   powershell -File tools/stop_game.ps1 -Port 9101   # WK-130: stop ONLY the game serving port 9101 (+ its launcher)
#   powershell -File tools/stop_game.ps1              # stop EVERY Godot process (other agents' games too!)
param([int]$Port = -1)

if ($Port -lt 0) {
    Get-Process | Where-Object { $_.ProcessName -like 'Godot*' } | Stop-Process -Force -ErrorAction SilentlyContinue
    Write-Output "Godot processes stopped."
    exit 0
}

$listener = 0
foreach ($line in (netstat -ano -p TCP)) {
    $f = ($line.Trim() -split '\s+')
    if ($f.Count -ge 5 -and $f[3] -eq 'LISTENING' -and $f[1] -match (':' + $Port + '$')) { $listener = [int]$f[4]; break }
}
if ($listener -eq 0) { Write-Output "Nothing is listening on port $Port."; exit 0 }

$lp = Get-CimInstance Win32_Process -Filter "ProcessId=$listener" -ErrorAction SilentlyContinue
if (-not $lp -or $lp.Name -notlike 'Godot*') {
    Write-Output "Port $Port is held by PID $listener ($($lp.Name)), not Godot - not touching it."
    exit 1
}
$ids = @($listener)
# The _console.exe launcher is the parent of the real game process; stop it too.
$parent = Get-CimInstance Win32_Process -Filter "ProcessId=$($lp.ParentProcessId)" -ErrorAction SilentlyContinue
if ($parent -and $parent.Name -like 'Godot*') { $ids += [int]$parent.ProcessId }
Stop-Process -Id $ids -Force -ErrorAction SilentlyContinue
Write-Output "Stopped Godot PID(s) $($ids -join ',') (port $Port)."
