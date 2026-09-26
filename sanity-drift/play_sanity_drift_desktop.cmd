@echo off
setlocal
set "GODOT_EXE=%USERPROFILE%\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe"
if not exist "%GODOT_EXE%" (
  echo Godot 4.7.1 was not found in the expected Downloads folder.
  echo Open project.godot manually with Godot 4.7 or newer.
  pause
  exit /b 1
)
start "Sanity Drift Desktop" "%GODOT_EXE%" --path "%~dp0" --xr-mode off -- --desktop
