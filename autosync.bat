@echo off
rem Keeps this folder in step with GitHub: pulls new commits every 60 seconds.
rem Leave this window open while you play or work; close it to stop.
rem It only fast-forwards, so it never overwrites local edits you have not pushed.
cd /d "%~dp0"
title Mach Math auto-sync
:loop
git pull --ff-only --quiet && echo [%time:~0,8%] Up to date.
timeout /t 60 /nobreak >nul
goto loop
