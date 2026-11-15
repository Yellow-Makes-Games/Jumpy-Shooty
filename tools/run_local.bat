@echo off
rem Opens several copies of Jumpy Shooty on this PC, already connected to each other.
rem The first copy hosts; the others join it. Close any window to quit that copy.
rem
rem Usage:  tools\run_local.bat [PLAYERS]      (PLAYERS = 2 to 5, default 2)
rem
rem Set GODOT to your Godot executable if it is not on your PATH, for example:
rem   set GODOT=C:\Godot\Godot_v4.7.2-stable_win64.exe
setlocal
cd /d "%~dp0.."
if "%GODOT%"=="" set GODOT=godot
set PLAYERS=%1
if "%PLAYERS%"=="" set PLAYERS=2

start "Host" "%GODOT%" --path . -- --host --name=Host --window=0,40,960,540
timeout /t 2 /nobreak >nul
if %PLAYERS% GEQ 2 start "P2" "%GODOT%" --path . -- --join=127.0.0.1 --name=P2 --window=960,40,960,540
if %PLAYERS% GEQ 3 start "P3" "%GODOT%" --path . -- --join=127.0.0.1 --name=P3 --window=0,580,960,540
if %PLAYERS% GEQ 4 start "P4" "%GODOT%" --path . -- --join=127.0.0.1 --name=P4 --window=960,580,960,540
if %PLAYERS% GEQ 5 start "P5" "%GODOT%" --path . -- --join=127.0.0.1 --name=P5 --window=480,300,960,540
endlocal
