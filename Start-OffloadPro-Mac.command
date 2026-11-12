#!/usr/bin/env bash
# ==============================================================================
# OffloadPro DIT Studio v4.4.0 - Native macOS Launcher (Double-Clickable in Finder)
# Zero Node.js | Zero Localhost Server | Native AppleScript + PowerShell 7 (pwsh)
# ==============================================================================
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "================================================================"
echo "OffloadPro DIT Studio v4.4.0 (macOS Native Edition)"
echo "================================================================"

if command -v pwsh >/dev/null 2>&1; then
    echo "[OK] PowerShell 7 (pwsh) detected. Launching native macOS Folder Picker workflow..."
    pwsh -NoProfile -Command "Import-Module '$SCRIPT_DIR/modules/OffloadPro/OffloadPro.psd1' -Force; Start-OffloadProApp"
else
    echo "[INFO] PowerShell 7 (pwsh) not yet installed (install via: brew install --cask powershell)."
    echo "[INFO] Opening Offline OffloadPro Studio HTML Dashboard in default browser..."
    open "$SCRIPT_DIR/public/index.html"
fi
