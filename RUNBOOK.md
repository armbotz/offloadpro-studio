# Operational Runbook & Knowledge Base: OffloadPro DIT Studio & Large SD Card Offload Workflow

**Document ID:** KB-STORAGE-001  
**Version:** 2.0.0  
**Applies To:** Windows 10 / 11 (PowerShell 5.1+ / 7+), Node.js 18+, FFmpeg 8+, `exFAT` / `FAT32` Media Cards  

---

## Part A: OffloadPro DIT Studio App Runbook (GUI Workflow)

### Step 1: Launch the Studio Server
1. Double-click [`Start-OffloadPro-Studio.bat`](./Start-OffloadPro-Studio.bat) or run:
   ```powershell
   node server.js
   ```
2. Open **http://localhost:4789** in your browser.
3. Verify your source card (e.g., `D:\` marked `Removable • exFAT • 128 KB blocks`) and destination archive drive (e.g., `E:\` marked `Fixed • NTFS • 4 KB blocks`) appear in **Column 1 (Mounted Drives & Block Slack)**.

### Step 2: Run Pre-Flight Source X-Ray
1. Click the source SD card in **Column 1** (or enter its path in **Pre-Flight Source / Backup X-Ray** and click **Scan Path**).
2. Review the pre-flight metrics before copying:
   - **Real Media/User Files:** Exact count and byte total of your real `.MOV`, `.MP4`, `.JPG`, `.WAV`, `.MP3`, and `.PDF` files.
   - **macOS `._*` 4 KB Sidecars:** Count of AppleDouble metadata companion files created if the card was mounted on a Mac.
   - **System / Forensic (`.Spotlight-V100`):** Indicates whether macOS Spotlight database files (`store.db`) or `.Trashes` exist on the card.
   - **exFAT 128 KB Cluster Slack Overhead:** Explains any discrepancy (typically 300–500 MB) between Windows Drive Properties "Used Space" on `exFAT` and Folder Properties "Size" on `NTFS`.

### Step 3: Configure & Start the Single-Read Verified Offload
In **Column 2 (ShotPut Pro Single-Read Offload Queue)**:
1. **Source Card / Directory:** Set to `D:\` (or your card's drive root).
2. **Primary Destination Path:** Set to your target backup folder (e.g., `E:\Backups\Card_001`).
3. **Secondary Simultaneous Destination (Optional):** Enter a second drive path to stream to two drives simultaneously from a single read of the SD card.
4. **Checksum Algorithm:** Select `MD5` (fastest industry standard for video offload) or `SHA256`.
5. **macOS Metadata Mode:**
   - **Forensic Split (Recommended):** Copies clean media to your primary destination and routes `._*` and `.Spotlight-V100` into `<Destination>_forensics`.
   - **Option 2 (Clean):** Skips `._*`, `.DS_Store`, `.Spotlight-V100`, `.Trashes`, and `System Volume Information`.
   - **Option 1 (True Raw 1:1):** Mirrors all files into the primary destination.
6. **3-Level Verification Pipeline:**
   - Enable **Level 1 (Inline Source Read + Destination Readback Hash)** and **Level 2 (`ffprobe` Container Check)** for all offloads.
   - Enable **Level 3 (`ffmpeg` Deep End-to-End Frame/Stream Decode)** when auditing archival cards for historical mid-stream flash sector bitrot.
7. Click **▶ Start Single-Read Verified Offload** and monitor live progress, speed (`MB/s`), and verification counters in **Column 3**.

### Step 4: Generate Certificates & Run Post-Transfer Forensics
In **Column 3 (Post-Transfer Forensic & Certificate Toolkit)**:
1. Click **📜 Generate ASC-MHL (`.mhl`) + HTML Certificate** to write `<BackupName>.mhl` and `<BackupName>_Offload_Certificate.html`.
2. Click **🔍 Reverse-Engineer macOS `._*` Metadata Strings** to extract any hidden download URLs (`kMDItemWhereFroms`), AirDrop sender names, or quarantine timestamps into `mac_metadata_findings.txt`.
3. Click **🧪 Dry-Run Count `._*` & `.DS_Store` Junk** to preview sidecar removal, then **🗑️ Purge All `._*` & `.DS_Store` Files** if you ran a Raw copy and want to clean up the destination folder.
4. Confirm the top-right banner reads **`● SD CARD VERIFIED 100% — SAFE TO FORMAT`** before formatting the SD card.

---

## Part B: Standalone CLI / PowerShell Runbook (`robocopy` + 3-Level Audit)

When performing an offload or audit purely from PowerShell without the Web UI, follow this step-by-step runbook.

### 1. Pre-Flight Drive Check & Sleep Prevention
```powershell
# Inspect mounted drives and free space
Get-PSDrive -PSProvider FileSystem | Select-Object Name,
    @{N='Used(GB)';E={[math]::Round($_.Used/1GB,2)}},
    @{N='Free(GB)';E={[math]::Round($_.Free/1GB,2)}},
    Root

# Prevent Windows AC sleep during transfer
powercfg /change standby-timeout-ac 0
```

### 2. One-Shot Buffered Offload (`robocopy`)
> **IMPORTANT:** Always pass `D:\` **without quotes** (`D:\`, not `"D:\"`). In Windows C-runtime argv parsing, `"D:\"` treats `\"` as an escaped quote.

#### Option 1: True Raw Copy (Excludes only system/trash directories)
```powershell
robocopy D:\ "E:\Backups\Camera_Offload_001" /E /COPY:DAT /DCOPY:DAT /MT:4 /R:5 /W:3 /XJ /XD "System Volume Information" ".Spotlight-V100" ".Trashes" ".fseventsd" /LOG+:"E:\Backups\Camera_Offload_001_transfer.log" /TEE /NP
```

#### Option 2: Clean Copy (Also excludes macOS `._*` and `.DS_Store` during copy)
```powershell
robocopy D:\ "E:\Backups\Camera_Offload_001" /E /COPY:DAT /DCOPY:DAT /MT:4 /R:5 /W:3 /XJ /XD "System Volume Information" ".Spotlight-V100" ".Trashes" ".fseventsd" /XF "._*" ".DS_Store" /LOG+:"E:\Backups\Camera_Offload_001_transfer.log" /TEE /NP
```

#### Clear Root Hidden/System Attributes on Destination
When copying from a drive root (`D:\`), `robocopy` can copy the volume root's `+H +S` attributes onto the destination folder. Clear them with:
```powershell
attrib -s -h "E:\Backups\Camera_Offload_001"
```

#### Optional: Archive `.Spotlight-V100` & `.Trashes` for Forensic Inspection
Because `.Spotlight-V100\Store-V2` (`store.db`) retains historical metadata of deleted files from years past and `.Trashes\501` holds un-emptied macOS Trash files, you can archive them into a visible forensics folder:
```powershell
foreach ($dir in @(".Spotlight-V100", ".Trashes", "System Volume Information")) {
    robocopy "D:\$dir" "E:\Backups\Camera_Offload_001_system_forensics\$dir" /E /COPY:DAT /DCOPY:DAT /R:3 /W:1 /NP | Out-Null
    attrib -s -h "E:\Backups\Camera_Offload_001_system_forensics\$dir"
}
```

---

### 3. Running the 3-Level Integrity Audit via CLI Script
Run the included [`scripts/Invoke-3LevelAudit.ps1`](./scripts/Invoke-3LevelAudit.ps1) script to execute all three verification passes:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-3LevelAudit.ps1 `
    -SourceRoot "D:\" `
    -DestinationRoot "E:\Backups\Camera_Offload_001" `
    -Threads 6
```

#### What Each Audit Level Verifies:
1. **Level 1 (Bit-for-Bit `MD5` Hash Check):** Reads `D:\` and `E:\` concurrently across two threads to prove 100% mathematical bit-for-bit identity.
2. **Level 2 (`ffprobe` Container & `moov` Atom Check):** Validates that every `.MOV`, `.MP4`, `.3GP`, `.JPG`, `.WAV`, `.MP3`, `.M4A`, `.AIF`, and `.PDF` has an intact container, valid `moov` atom at the end of the file, and decodable initial keyframes.
3. **Level 3 (`ffmpeg` Deep End-to-End Stream Decode):** Demuxes 100% of every media file from start to finish and decodes all video keyframes (`-skip_frame nokey`), all audio streams, and all photos into a null sink (`-f null -`), automatically falling back to standard decode (`-i <file> -f null -`) for audio-only files so `-skip_frame` never throws `-22 (Invalid argument)`.

---

### 4. Running the macOS `._*` Forensic String Dump & Cleanup via CLI Script
Run the included [`scripts/Invoke-MacMetadataForensics.ps1`](./scripts/Invoke-MacMetadataForensics.ps1) script:

```powershell
# Step 1: Dump readable metadata strings from ._* files to E:\Backups\mac_metadata_findings.txt and preview junk file count (Dry-Run)
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-MacMetadataForensics.ps1 `
    -TargetPath "E:\Backups\Camera_Offload_001" `
    -ReportPath "E:\Backups\mac_metadata_findings.txt"

# Step 2: Delete all ._* and .DS_Store files after reviewing the report
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-MacMetadataForensics.ps1 `
    -TargetPath "E:\Backups\Camera_Offload_001" `
    -ReportPath "E:\Backups\mac_metadata_findings.txt" `
    -DeleteJunkAfterDump
```
