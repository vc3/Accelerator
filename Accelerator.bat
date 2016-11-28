@echo off
@powershell -Version 2 -NoProfile -ExecutionPolicy Bypass -Command "cd '%~dp0\Scripts'; .\Start-Accelerator.ps1 %* -WorkingDirectory '%~dp0'"
