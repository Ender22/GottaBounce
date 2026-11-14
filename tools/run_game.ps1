# Launch the game windowed (rendered) so gbplay.py can drive it on port 9090.
# Usage: powershell -File tools/run_game.ps1 [scene] [-Wait] [-Resolution 1920x1080] [-Position 0,0]
param(
    [string]$Scene = "",
    [switch]$Wait,
    [string]$Resolution = "1280x720",
    [string]$Position = "50,50"
)
$godot = "C:\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe"
$proj = Split-Path $PSScriptRoot -Parent

# Kill any stale game instances first (zombie processes hog CPU and steal port 9090)
Get-Process | Where-Object { $_.ProcessName -like 'Godot*' } | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 300

$logPath = Join-Path $env:TEMP "gottabounce_run.log"
$argList = @("--path", "`"$proj`"", "--resolution", $Resolution, "--position", $Position)
if ($Scene -ne "") { $argList += $Scene }

$proc = Start-Process -FilePath $godot -ArgumentList $argList -PassThru `
    -RedirectStandardOutput $logPath -RedirectStandardError "$logPath.err"
Write-Output "Started PID $($proc.Id); log: $logPath"

# Wait for the TCP server to come up (max 20s)
$deadline = (Get-Date).AddSeconds(20)
$up = $false
while ((Get-Date) -lt $deadline) {
    try {
        $t = New-Object Net.Sockets.TcpClient
        $t.Connect("127.0.0.1", 9090)
        $t.Close()
        $up = $true
        break
    } catch { Start-Sleep -Milliseconds 500 }
}
if ($up) { Write-Output "Interaction server UP on 9090" }
else { Write-Output "WARNING: server not reachable after 20s - check $logPath" }
if ($Wait) { Wait-Process -Id $proc.Id }
