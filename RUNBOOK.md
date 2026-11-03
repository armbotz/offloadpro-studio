# Operational Runbook & Knowledge Base: OffloadPro DIT Studio v3.0 (Pure PowerShell + Offline Static HTML)

**Document ID:** KB-STORAGE-001  
**Version:** 3.0.0  
**Applies To:** Windows 10 / 11 (PowerShell 5.1+ / 7+), FFmpeg 8+, `exFAT` / `FAT32` Media Cards (Zero Node.js / Zero Server)

---

## Part A: Offline Static HTML Studio Workflow (`public\index.html`)

### Step 1: Open the Offline Studio UI
1. Double-click [`Start-OffloadPro-Studio.bat`](./Start-OffloadPro-Studio.bat) or open [`public/index.html`](./public/index.html) directly in your browser (`file://`). No background server or localhost port is started.
2. To refresh the mounted volume bay (`Get-Volume` + S.M.A.R.T. + Write-Protect Lock) and pre-flight snapshot from PowerShell, click **🔄 CLI Refresh Cmd** and run the copied command in your terminal:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-OffloadProEngine.ps1 -Action ExportTelemetry -TargetPath "E:\Backups\Camera_Offload_001"
   ```

### Step 2: Run Pre-Flight Source / Backup X-Ray
1. Click **📂 Scan Folder in Browser** in Column 1 to select a local folder or drive directly in your browser (computes real file counts, 3-Tier Sidecar Taxonomy, Live Photo pairs, `exFAT` 128 KB cluster slack waste, ThinkStats2 ECDF quantiles, and WebCrypto SHA-256 Merkle Root 100% client-side), **or** run the standalone PowerShell pre-flight X-Ray:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-OffloadProEngine.ps1 -Action Preflight -TargetPath "E:\Backups\Camera_Offload_001"
   ```

### Step 3: Configure & Run the Single-Read Verified Offload
In **Column 2 (ShotPut Pro Single-Read Offload Queue)**:
1. Configure **Source Card (`D:\`)**, **Primary Destination (`E:\Backups\Camera_Offload_001`)**, optional **Secondary Destination (`F:\Backups\Camera_Mirror_001`)**, **Checksum Algorithm (`SHA256` / `MD5`)**, **macOS Metadata Mode (`forensic_split` / `clean` / `raw`)**, and **Verification Levels 1–3**.
2. Click **⚡ Generate & Copy Pure PowerShell Offload Command** (or **🚀 Generate High-Speed Robocopy + 3-Level Audit Command**) and paste the command into your standalone PowerShell terminal:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-OffloadProEngine.ps1 `
     -Action Offload `
     -SourceRoot "D:\" `
     -DestinationRoot "E:\Backups\Camera_Offload_001" `
     -Algorithm SHA256 `
     -MacMode forensic_split `
     -VerifyLevel1 $true -VerifyLevel2 $true -VerifyLevel3 $false
   ```

### Step 4: Generate Certificates & Run Post-Transfer Forensics
Use the buttons in **Column 3** to copy the exact standalone PowerShell commands for:
1. **📜 Generate ASC-MHL (`.mhl`) + Offline Visual Contact-Sheet HTML Certificate:**
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-OffloadProEngine.ps1 -Action Certificate -TargetPath "E:\Backups\Camera_Offload_001" -Algorithm SHA256
   ```
2. **🔍 Extract macOS `._*` AppleDouble Forensic Strings & Preview Tier-2 OS Junk:**
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-MacMetadataForensics.ps1 -TargetPath "E:\Backups\Camera_Offload_001"
   ```
3. **🗑️ Purge Tier-2 OS Junk (`._*`, `.DS_Store`, `Thumbs.db`) while protecting `.AAE` / `.XMP`:**
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-MacMetadataForensics.ps1 -TargetPath "E:\Backups\Camera_Offload_001" -DeleteJunkAfterDump
   ```

---

## Part B: Direct `robocopy` + 3-Level Audit CLI Runbook

### 1. Pre-Flight Drive Check & Sleep Prevention
```powershell
Get-PSDrive -PSProvider FileSystem | Select-Object Name,
    @{N='Used(GB)';E={[math]::Round($_.Used/1GB,2)}},
    @{N='Free(GB)';E={[math]::Round($_.Free/1GB,2)}},
    Root

powercfg /change standby-timeout-ac 0
```

### 2. One-Shot Buffered Offload (`robocopy`)
> **IMPORTANT:** Always pass `D:\` **without quotes** (`D:\`, not `"D:\"`). In Windows C-runtime argv parsing, `"D:\"` treats `\"` as an escaped quote.

#### Option 1: True Raw Copy (Excludes only system/trash directories)
```powershell
robocopy D:\ "E:\Backups\Camera_Offload_001" /E /COPY:DAT /DCOPY:DAT /MT:4 /R:5 /W:3 /XJ /XD "System Volume Information" ".Spotlight-V100" ".Trashes" ".fseventsd" /LOG+:"E:\Backups\Camera_Offload_001_transfer.log" /NP
attrib -s -h "E:\Backups\Camera_Offload_001"
```

#### Option 2: Clean Copy (Also excludes macOS `._*` and `.DS_Store` during copy)
```powershell
robocopy D:\ "E:\Backups\Camera_Offload_001" /E /COPY:DAT /DCOPY:DAT /MT:4 /R:5 /W:3 /XJ /XD "System Volume Information" ".Spotlight-V100" ".Trashes" ".fseventsd" /XF "._*" ".DS_Store" "Thumbs.db" "desktop.ini" /LOG+:"E:\Backups\Camera_Offload_001_transfer.log" /NP
attrib -s -h "E:\Backups\Camera_Offload_001"
```

### 3. Running the 3-Level Integrity Audit via CLI Script
```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-3LevelAudit.ps1 `
    -SourceRoot "D:\" `
    -DestinationRoot "E:\Backups\Camera_Offload_001" `
    -Threads 6
```
