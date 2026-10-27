@echo off
cd /d "%~dp0"
echo Starting SnipSnap at http://localhost:8123 ...
start "" http://localhost:8123
npx -y serve -l 8123 .
