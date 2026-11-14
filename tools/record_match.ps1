# WK-93: record a scripted match with Godot Movie Maker (fixed fps, every frame rendered at a
# deterministic timestep regardless of machine speed) + per-frame data log + contact sheets.
#
# Usage (from repo root):
#   powershell -File tools/record_match.ps1 -Name brawl20 [-Mode brawl] [-Arena pendulum_heights]
#       [-Levels 3,3,3,3] [-Seconds 20] [-Fps 30] [-Seed 7] [-AimLegacy] [-HazardLegacy]
#       [-PendulumTest 5] [-Every 10] [-Format avi|png] [-KeepPng] [-NoStamp] [-Force]
#
# -Format avi (default): Movie Maker writes MJPEG movie.avi (fast: JPEG per frame), rec_sheet.py splits it
#   into frameNNNNNNNN.jpg. -Format png: lossless frameNNNNNNNN.png (slow, ~1 s/frame at 1080p; huge).
# Output: tools/out/rec/<Name>/frame00000000.jpg ... (png kept only with -Format png -KeepPng), data.json,
#         sheet.png (contact sheet), sheet_overlay.png (with per-player markers/aim lines), aim_report.png,
#         plus a text summary from rec_sheet.py.
# WK-130: the recording runs with --gb-port=0, so it binds NO automation port and can run alongside other
# agents' games/recordings (Movie Maker frames are fixed-step, so CPU sharing does not change the output).
# -Force is kept for old command lines and is now a no-op. Never kill another agent's game.
param(
    [Parameter(Mandatory = $true)][string]$Name,
    [string]$Mode = "brawl",
    [string]$Arena = "",
    [string]$Levels = "3,3,3,3",
    [double]$Seconds = 20,
    [int]$Fps = 30,
    [int]$Seed = -1,
    [switch]$AimLegacy,
    [switch]$HazardLegacy,
    [int]$PendulumTest = 0,
    [int]$Every = 10,
    [ValidateSet("avi", "png")][string]$Format = "avi",
    [switch]$KeepPng,
    [switch]$NoStamp,
    [switch]$Force,
    [ValidateSet("on", "baa", "off")][string]$Ghosts = "on",
    [int]$Lives = 1,
    [string]$Eliminate = ""
)
$ErrorActionPreference = "Stop"
$godot = "C:\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64_console.exe"
$proj = Split-Path $PSScriptRoot -Parent
$recRoot = Join-Path $proj "tools\out\rec"
$outDir = Join-Path $recRoot $Name

# WK-100: display-off pre-flight. Movie Maker frames stay deterministic, but a sleeping display throttles
# the wall clock to ~30 Hz with 500 ms stalls (or freezes Godot) - warn, never block.
$displayCheck = Join-Path $PSScriptRoot "display_check.ps1"
if (Test-Path $displayCheck) { try { & $displayCheck } catch { } ; $global:LASTEXITCODE = 0 }

New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$gdi = Join-Path $recRoot ".gdignore"
if (-not (Test-Path $gdi)) { New-Item -ItemType File -Path $gdi | Out-Null }
Get-ChildItem -Path $outDir -Filter "frame*" -ErrorAction SilentlyContinue | Remove-Item -Force
Get-ChildItem -Path $outDir -Filter "movie.avi" -ErrorAction SilentlyContinue | Remove-Item -Force

# Frame cap = boot + intro/countdown + between-stage score screens + the requested COMBAT seconds. The
# recorder quits on its own after <Seconds> of COMBAT time; --quit-after is only a safety net.
$frames = [int]((2 * $Seconds + 20) * $Fps)
$moviePath = if ($Format -eq "avi") { Join-Path $outDir "movie.avi" } else { Join-Path $outDir "frame.png" }
$user = @("name=$Name", "mode=$Mode", "levels=$Levels", "seconds=$Seconds")
if ($Arena -ne "") { $user += "arena=$Arena" }
if ($Seed -ge 0) { $user += "seed=$Seed" }
if ($AimLegacy) { $user += "aim_legacy=1" }
if ($HazardLegacy) { $user += "hazard_legacy=1" }
if ($PendulumTest -gt 0) { $user += "pendulum_test=$PendulumTest" }
if ($NoStamp) { $user += "stamp=0" }
$user += "ghosts=$Ghosts"
$user += "lives=$Lives"
if ($Eliminate -ne "") { $user += "eliminate=$Eliminate" }
$user += "--gb-port=0"   # WK-130: no automation server in recordings (never steals/binds a port)

$argList = @("--path", "`"$proj`"", "--resolution", "1280x720", "--position", "50,50",
    "--write-movie", "`"$moviePath`"", "--fixed-fps", "$Fps", "--quit-after", "$frames",
    "res://scenes/dev/RecordBoot.tscn", "--") + $user
$logPath = Join-Path $outDir "godot.log"
Write-Output "Recording '$Name' ($Mode / $Arena / bots $Levels / $Seconds s @ $Fps fps, cap $frames frames)..."
$sw = [Diagnostics.Stopwatch]::StartNew()
$proc = Start-Process -FilePath $godot -ArgumentList $argList -PassThru -Wait `
    -RedirectStandardOutput $logPath -RedirectStandardError "$logPath.err"
$sw.Stop()
Write-Output ("Godot exited ({0}) after {1:N1} s wall." -f $proc.ExitCode, $sw.Elapsed.TotalSeconds)
if (-not (Test-Path (Join-Path $outDir "data.json"))) {
    Write-Output "WARNING: data.json missing - the recorder did not finish. See $logPath(.err)"
}

$py = @("tools/rec_sheet.py", $outDir, "--every", "$Every", "--overlay", "--report", "--traj")
if (-not $KeepPng) { $py += "--compact" }
Push-Location $proj
try { & python @py } finally { Pop-Location }
