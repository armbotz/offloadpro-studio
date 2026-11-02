@echo off
title OffloadPro DIT Studio
echo Starting OffloadPro DIT Studio on http://localhost:4789 ...
start "" "http://localhost:4789"
node "%~dp0server.js"
pause
