# Operational Runbook & Knowledge Base: OffloadPro DIT Studio v3.1 (Lead DIT Edition)

**Document ID:** KB-STORAGE-001  
**Version:** 3.1.0  
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

### Step 3: Configure & Run the Single-Read Verified Offload (With Cart Safety Gates)
In **Column 2 (ShotPut Pro Single-Read Offload Queue)**:
1. Configure **Source Card (`D:\`)**, **Primary Destination (`E:\Backups\Camera_Offload_001`)**, optional **Secondary Destination (`F:\Backups\Camera_Mirror_001`)**, **Checksum Algorithm (`SHA256` / `MD5`)**, **macOS Metadata Mode (`forensic_split` / `clean` / `raw`)**, and **Verification Levels 1–3**.
2. Click **⚡ Generate & Copy Pure PowerShell Offload Command** and paste it into your standalone PowerShell terminal:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-OffloadProEngine.ps1 `
     -Action Offload `
     -SourceRoot "D:\" `
     -DestinationRoot "E:\Backups\Camera_Offload_001" `
     -Algorithm SHA256 `
     -MacMode forensic_split `
     -VerifyLevel1 $true -VerifyLevel2 $true -VerifyLevel3 $false
   ```
   - **Pre-Flight Safety Gates:** Automatically verifies destination free space (`Payload + 5% NTFS headroom`) and checks for roll-name collisions before writing a single byte, then seals 100% of the roll into `<BackupName>.mhl` using the inline RAM hashes.

### Step 4: 5-Second "Safe to Pull Card" Parity Diff (`Source D:\` vs. `Backup E:\`)
In **Column 2 (⚖️ 5-Second "Safe to Pull Card" Parity Diff)**:
1. Click **📂 1. Pick Source (`D:\`)** and select your SD card root.
2. Click **📂 2. Pick Backup (`E:\`)** and select your destination backup folder.
3. Confirm the badge lights up **`✓ 100% TREE & BYTE PARITY MATCH — SAFE TO PULL CARD`** (`0 Missing on Backup`, `0 Size Mismatches`, identical `SHA-256` Merkle Roots) before pulling the card to format in-camera.

### Step 5: Full-Roll ASC-MHL Sealing, Bitrot Verification & Post-Transfer Forensics
Use the buttons in **Column 3** to copy the standalone PowerShell commands or inspect `.mhl` files in your browser:
1. **📜 Seal 100% Full-Roll ASC-MHL (`.mhl`) + Duration/Codec Certificate (Multi-Threaded):**
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-OffloadProEngine.ps1 -Action Certificate -TargetPath "E:\Backups\Camera_Offload_001" -Algorithm SHA256 -Threads 6
   ```
2. **🛡️ Verify Existing `.MHL` Seal (Multi-Threaded Bitrot & Vault Scrub):**
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-OffloadProEngine.ps1 -Action VerifyMhl -TargetPath "E:\Backups\Camera_Offload_001" -Threads 6
   ```
3. **📄 Inspect `.MHL` XML Ledger in Browser:** Click to select any `.mhl` file and view sealed file counts, byte totals, algorithm, and Merkle seal client-side.
4. **🔍 Extract macOS `._*` AppleDouble Forensic Strings & Clean Tier-2 OS Junk:**
   ```powershell
   # Dry-run preview
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-MacMetadataForensics.ps1 -TargetPath "E:\Backups\Camera_Offload_001"

   # Delete Tier-2 OS junk (._*, .DS_Store, Thumbs.db) while protecting Tier-1 creative sidecars (.AAE/.XMP/.SRT)
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-MacMetadataForensics.ps1 -TargetPath "E:\Backups\Camera_Offload_001" -DeleteJunkAfterDump
   ```
