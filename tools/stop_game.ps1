# Stop all running Godot instances (game + strays). Safe to run anytime.
Get-Process | Where-Object { $_.ProcessName -like 'Godot*' } | Stop-Process -Force -ErrorAction SilentlyContinue
Write-Output "Godot processes stopped."
