@echo off
rem Double-clickable launcher for the dev build; see run-client.ps1.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-client.ps1" %*
