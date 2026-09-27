@echo off
setlocal
set "GODOT_EXE=%USERPROFILE%\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64.exe"
set "STEAMXR_RUNTIME=C:\Program Files (x86)\Steam\steamapps\common\SteamVR\steamxr_win64.json"

if not exist "%GODOT_EXE%" (
  echo Godot 4.7.1 was not found in the expected Downloads folder.
  echo Open project.godot manually with Godot 4.7 or newer.
  pause
  exit /b 1
)

if not exist "%STEAMXR_RUNTIME%" (
  echo SteamVR OpenXR runtime was not found in the default Steam folder.
  echo Start SteamVR and set it as the current OpenXR runtime, then try again.
  pause
  exit /b 1
)

set "XR_RUNTIME_JSON=%STEAMXR_RUNTIME%"
start "Sanity Drift Vive" "%GODOT_EXE%" --path "%~dp0" --xr-mode on
