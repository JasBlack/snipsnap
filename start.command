#!/bin/bash
# SnipSnap launcher for macOS. If double-clicking doesn't work, first run:
#   chmod +x start.command
cd "$(dirname "$0")"
echo "Starting SnipSnap at http://localhost:8123 ..."
(sleep 2 && open http://localhost:8123) &
npx -y serve -l 8123 .
