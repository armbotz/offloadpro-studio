# Operational Runbook, Knowledge Base & FAQ: OffloadPro DIT Studio v4.4

**Document ID:** KB-STORAGE-001  
**Version:** 4.4.0  
**Applies To:** Windows 10 / 11 (Windows PowerShell 5.1 & PowerShell 7+), FFmpeg 8+, `exFAT` / `FAT32` / `NTFS` Media Volumes (100% Zero Node.js / Zero Server)

---

## Part 1: Step-by-Step Operational Runbook

### Step 1: Launch OffloadPro Studio (Native Windows Desktop App, macOS Finder, or Offline HTML)
1. **Native Windows Desktop App (Recommended):**
   - Double-click [`Start-OffloadPro-Studio.bat`](./Start-OffloadPro-Studio.bat) (or compile and launch `OffloadProStudio.exe` via `.\scripts\Build-OffloadProExe.ps1`, or run `Start-OffloadProApp` after importing `OffloadPro.psd1`).
   - Use **Auto-Detect Card**, **Next Roll (`+001`)**, **Step 1: X-Ray Source Card**, and **Step 2: Start Verified Offload & Seal** directly inside the native desktop window.
2. **Native macOS Finder App:**
   - Double-click [`Start-OffloadPro-Mac.command`](./Start-OffloadPro-Mac.command) to select `/Volumes/<Card>` and your backup vault using native macOS Finder dialogs.
3. **Offline Static HTML Studio (`file://`):**
   - Run `Start-OffloadPro-Studio.bat --html` or open [`public/index.html`](./public/index.html) directly in any browser (`file://`). No background process, daemon, or localhost port is started.
4. **10-Foot Ambient Status Halo & DIT Soundscape:**
   - Glance at the perimeter halo of your browser window: **Green** indicates complete parity, **Red** alerts to missing files/rot, **Amber** warns of ongoing analysis or partial checks, and **Blue** highlights card insertion.
   - Click the **🔊 DIT Audio Chimes** toggle in the top-right toolbar to enable audible Hollywood DIT chimes (synthesized purely via Web Audio API without loading external sound files).
3. **(Optional) Export Hardware Volume Telemetry to the Offline UI:**
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-OffloadProEngine.ps1 -Action ExportTelemetry -TargetPath "E:\Backups\Camera_Offload_001"
   ```
   This queries Windows CIM/WMI (`Get-Volume`, `Get-Partition`, `Get-PhysicalDisk`, `Win32_LogicalDisk`) for hardware volume serial numbers, S.M.A.R.T. health, and SD write-protect tab status, writing aggregate metrics into [`public/offloadpro-telemetry.js`](./public/offloadpro-telemetry.js).

---

### Step 2: Run Pre-Flight X-Ray & Camera OEM Recognizer
Before copying a single byte, inspect the source card for **Camera Sequence Numbering Gaps** (e.g., `C0001`, `C0002`, `C0004` missing `C0003`), **Spanned-Clip Sub-Parts**, **Orphan Sidecars**, **Live Photo Pairs**, **Camera OEM Folder Signatures** (`Sony M4ROOT\CLIP`, `RED .R3D`, `Blackmagic .BRAW`, `Canon`, `DJI`, `Apple iOS`), and **`exFAT` 128 KB Cluster Slack Waste**:

- **In Browser (Zero CLI):** Click **📂 Scan Folder in Browser** in Column 1 of [`public/index.html`](./public/index.html).
- **Via PowerShell CLI:**
  ```powershell
  powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-OffloadProEngine.ps1 -Action Preflight -TargetPath "D:\"
  ```

---

### Step 3: Execute Single-Read Multi-Destination Offload (With Crash-Resume & NLE Seals)
Reads each 4 MB block from the SD card **only once** (`FileOptions.SequentialScan`), computes inline cryptographic hashes (`SHA256` / `MD5` / `SHA1`) in RAM, writes simultaneously to Copy #1 (`E:\`) and Copy #2 (`F:\`), flushes OS hardware buffers (`$os.Flush($true)` / Win32 `FlushFileBuffers`), verifies destination readback, and seals **four post-house deliverables** (`.mhl`, `.ale`, `.csv`, `.html`):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-OffloadProEngine.ps1 `
  -Action Offload `
  -SourceRoot "D:\" `
  -DestinationRoot "E:\Backups\Camera_Offload_001" `
  -SecondaryDestinationRoot "F:\Backups\Camera_Mirror_001" `
  -CameraId "CamA" -RollId "A001" `
  -Algorithm SHA256 `
  -MacMode forensic_split `
  -VerifyLevel1 $true -VerifyLevel2 $true -VerifyLevel3 $false
```
- **Idempotent Crash-Resumable Checkpoint:** If a power outage or cable bump interrupts a transfer at 80%, re-run the exact same command. Intact files matching byte length and `LastWriteTimeUtc` are verified in place (`Resumed: N`) without re-reading them from the SD card.

---

### Step 4: 5-Second "Safe to Pull Card" Parity Diff (`Source D:\` vs. `Backup E:\`)
In **Column 2** of [`public/index.html`](./public/index.html):
1. Click **📂 1. Pick Source (`D:\`)** and select your SD card.
2. Click **📂 2. Pick Backup (`E:\`)** and select your backup folder.
3. Verify the banner turns green: **`🟢 100% SOURCE VS. BACKUP MERKLE PARITY MATCH — SAFE TO PULL CARD`**.
   - Or run the CLI cross-archive Merkle comparator:
     ```powershell
     powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-OffloadProEngine.ps1 -Action CompareArchives -SourceRoot "D:\" -DestinationRoot "E:\Backups\Camera_Offload_001"
     ```

---

### Step 5: Long-Term Vault Scrubbing (`VerifyMhl`) & Self-Healing Bitrot Repair (`HealFromMirror`)
1. **Quarterly Cold-Storage Bitrot Scrub (`-Action VerifyMhl`):**
   Re-hashes every file in your backup against its sealed `<BackupName>.mhl` XML manifest across 6 threads:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-OffloadProEngine.ps1 -Action VerifyMhl -TargetPath "E:\Backups\Camera_Offload_001" -Threads 6
   ```
2. **Self-Healing Bitrot Repair from Mirror (`-Action HealFromMirror`):**
   If `VerifyMhl` detects a corrupted or missing file on `E:\` (`ExitCode = 1`), repair it automatically from your secondary 3-2-1 mirror (`F:\`). The engine hashes the mirror copy first, proves mathematically that it matches the original `.mhl` seal, and atomically repairs the primary copy:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-OffloadProEngine.ps1 `
     -Action HealFromMirror `
     -TargetPath "E:\Backups\Camera_Offload_001" `
     -SourceRoot "F:\Backups\Camera_Mirror_001" `
     -Threads 6
   ```

---

### Step 6: Automated Editorial & Dailies Proxies (`GenerateProxies`)
Generate lightweight 1080p or 720p H.264 proxy files that mirror the master camera folder tree for 1-click DaVinci Resolve and Premiere Pro proxy relinking:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-OffloadProEngine.ps1 `
  -Action GenerateProxies `
  -TargetPath "E:\Backups\Camera_Offload_001" `
  -ProxyResolution 1080p `
  -ProxyEncoder cpu `
  -Threads 4
```
- **Optional Client / Director Window-Burn:** Add `-ProxyBurnIn` to burn a lower-third roll and clip slate directly into the video frames.
- **Idempotent Proxy Checkpoint:** Automatically skips already-rendered proxy clips (`Resumed/Cached: N`).

---

### Step 7: Reversible DIT Safe Card Release (`Clear-CameraCard` & `Undo-CardClear`)
When releasing an offloaded card back to the 2nd AC (Camera Assistant), signal that it has been 100% verified by reversibly inverting the first 2 MiB (MBR/GPT/exFAT Boot Sector). The camera will immediately prompt for a clean in-camera format upon insertion, preventing duplicate recording or accidental erasure of un-offloaded cards.

OffloadPro v4.4 dispatches Win32 `DeviceIoControl` control codes (`FSCTL_LOCK_VOLUME` `0x00090018` and `FSCTL_DISMOUNT_VOLUME` `0x00090020`) before modifying raw volume sectors, ensuring open Windows Explorer handles or background indexing services cannot cause access-denied locks:

```powershell
# Via PowerShell Module:
Import-Module .\modules\OffloadPro\OffloadPro.psd1

# 1. Fake-Format (Inverts 2 MiB header after verifying 100% Merkle parity with backup)
Clear-CameraCard -CardPath "D:\" -VerifiedBackupPath "E:\Backups\Camera_Offload_001"

# 2. Emergency Restore (If someone realizes a clip was missing, revert bits back in 1 second)
Undo-CardClear -CardPath "D:\"

# Direct Engine Script equivalent:
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-OffloadProEngine.ps1 `
  -Action FakeFormatCard -SourceRoot "D:\" -DestinationRoot "E:\Backups\Camera_Offload_001"
```

---

### Step 8: Non-Destructive Date Organization (`OrganizeByDate`) & Two-Stage Deduplication (`DedupeScan`)
1. **Organize Messy Camera Dumps into `YYYY\YYYY-MM-DD` (Glues Live Photos & `.AAE`/`.XMP` Sidecars):**
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-OffloadProEngine.ps1 `
     -Action OrganizeByDate `
     -SourceRoot "E:\Backups\Camera_Offload_001" `
     -DestinationRoot "E:\Backups\Camera_Organized_By_Date"
   ```
   *(Add `-UseHardlinks` when organizing on the same NTFS drive to consume 0 extra bytes of disk space.)*
2. **Two-Stage $O(1)$ Size + Multi-Threaded Hash Deduplication Scan (`-Action DedupeScan`):**
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-OffloadProEngine.ps1 `
     -Action DedupeScan `
     -TargetPath "E:\Backups\Camera_Offload_001" `
     -Algorithm SHA256 -Threads 6
   ```

---

## Part 2: Architecture Knowledge Base (KB) — How All the Scripting Works

### 1. [`scripts/Invoke-OffloadProEngine.ps1`](./scripts/Invoke-OffloadProEngine.ps1) (The Master Engine)
This script is the core brain of OffloadPro. Every function inside it is written in pure 7-bit ASCII PowerShell so it runs identically on built-in Windows PowerShell 5.1 (`powershell.exe`) and PowerShell 7+ (`pwsh.exe`):

| Function Name | What It Does Under the Hood |
| :--- | :--- |
| **`Set-ExecutionAwakeLock`** | P/Invokes Win32 `kernel32.dll!SetThreadExecutionState(ES_CONTINUOUS \| ES_SYSTEM_REQUIRED)` inside a `try/finally` block so Windows never enters S3/Modern Standby sleep during a multi-hour 4K/8K offload. |
| **`Assert-SafeTargetPath`** | **Blast-Radius Guard:** Resolves the full canonical path (`[System.IO.Path]::GetFullPath`), blocks null/empty paths, and refuses to perform mutating writes directly on OS system roots (`C:\`, `C:\Windows`, `C:\Program Files`, `C:\Users`). |
| **`Assert-DestinationSafetyGates`** | Enforces two on-set DIT cart gates before copying: (1) **5% Free-Space Headroom Gate** (checks `DriveInfo.AvailableFreeSpace` against payload + `max(64 MB, 5%)`), and (2) **Roll-Name Collision Guard** (blocks overwriting an existing folder if any relative path has a different byte size). |
| **`Get-MountedVolumesTelemetry`** | Queries Windows CIM/WMI (`Get-Volume`, `Get-Partition`, `Get-PhysicalDisk`, `Win32_LogicalDisk`) to retrieve filesystem type (`exFAT`/`NTFS`), hardware Volume Serial Number, S.M.A.R.T. health, SD write-protect lock state, and macOS `.Spotlight-V100`/`.Trashes` footprints. |
| **`Invoke-PreflightScan`** | Walks a card or archive in one pass: classifies files into the **3-Tier Sidecar Taxonomy**, detects **Camera OEMs** (Sony `M4ROOT\CLIP`, RED `.R3D`, Blackmagic `.BRAW`, Canon, DJI, Apple iOS), warns if Sony `MEDIAPRO.XML` is missing, detects **Sequence Numbering Gaps** (`C0001` -> `C0004`) and **Spanned Clips**, computes **ThinkStats2 ECDF quantiles (`P10`–`P99`)**, and hashes the sorted relative tree into a **SHA-256 Merkle Structure Root**. |
| **`Copy-SingleReadMultiWrite`** | Opens the source file with `4 MB` buffers and `[System.IO.FileOptions]::SequentialScan` (instructing the Windows Cache Manager to double sequential read-ahead prefetching). As each 4 MB chunk is read into RAM, it feeds `.TransformBlock()` on the cryptographic hasher while writing to all destination `FileStream`s simultaneously, ending with `$os.Flush($true)` (Win32 `FlushFileBuffers`) so dirty OS RAM pages are physically committed to disk. |
| **`New-MhlAndCertificate`** | Seals 100% of the roll across `$MaxThreads` runspaces into `<BackupName>.mhl` (ASC-MHL XML), generates `<BackupName>.ale` (Avid/DaVinci Resolve Log Exchange) and `<BackupName>_PostHouse_Manifest.csv`, and builds `<BackupName>_Offload_Certificate.html` with `ffprobe` codec/resolution/duration badges and Base64 contact-sheet thumbnails. |
| **`Invoke-VerifyMhlLedger`** | Parses `<BackupName>.mhl` and verifies 100% of sealed files in parallel across `$MaxThreads` PowerShell runspaces, reporting `OK`, `MISSING`, `SIZE_MISMATCH`, or `HASH_MISMATCH` (`ExitCode = 1` on any bitrot). |
| **`Invoke-HealFromMirror`** | **Self-Healing 3-2-1 Vault:** Scans the primary archive against its `.mhl` ledger; for any missing or bit-rotted file, it verifies the corresponding file on the mirror drive against the original `.mhl` cryptographic hash and atomically repairs the primary file. |
| **`Invoke-FakeFormatCard`** | **Reversible Safe Card Release:** Inverts the first 2 MiB (partition table and exFAT boot sector) with bitwise XOR 0xFF, forcing cameras to prompt for in-camera format on next insert while saving an emergency header backup. |
| **`Invoke-RestoreCard`** | **Emergency Card Restoration:** Inverts the first 2 MiB back to its original byte state, instantly resurrecting all partitions, directories, and footage in 1 second. |
| **`Invoke-GenerateProxies`** | **Editorial & Dailies Proxy Engine:** Transcodes video clips into lightweight 1080p/720p H.264 MP4 (`-movflags +faststart`) preserving metadata and exact relative folder structures for 1-click DaVinci Resolve/Premiere Pro relinking, with optional lower-third burn-in (`-ProxyBurnIn`). |
| **`Invoke-OrganizeByDate`** | Non-destructively organizes files into `YYYY\YYYY-MM-DD` folders (via copy or instant NTFS hardlinks `-UseHardlinks`). Computes each clip group's canonical capture date from the primary photo/video first so `.AAE`/`.XMP` edits modified months later stay glued to their parent media's shoot date. |
| **`Invoke-DedupeScan`** | **Two-Stage Scalability Funnel:** Stage 1 groups all files by exact byte length (`$f.Length`) in memory with zero disk read I/O, eliminating 95%+ of unique-size files immediately. Stage 2 hashes only same-size candidates across `$MaxThreads` runspaces to report true cryptographic duplicates and reclaimable megabytes. |

---

### 2. [`scripts/Invoke-3LevelAudit.ps1`](./scripts/Invoke-3LevelAudit.ps1) (Multi-Threaded 3-Level Media Auditor)
Runs an independent, multi-threaded PowerShell RunspacePool (`1..$Threads`) audit comparing Source (`D:\`) and Destination (`E:\`):
- **Level 1 (Cryptographic Checksum):** Computes full-file `MD5` hashes on both Source and Destination to prove zero transit bit-flips.
- **Level 2 (`ffprobe` Container & `moov` Atom Check):** Inspects every `.MOV`/`.MP4` container header/trailer and decodes initial video keyframes (`-read_intervals "%+#3"`) plus JPEG/Audio/PDF headers.
- **Level 3 (`ffmpeg` Deep End-to-End Stream Decode):** Demuxes 100% of every media file from start to finish and decodes video keyframes (`-skip_frame nokey`), all audio frames, and all photos into `-f null -` to catch mid-stream flash sector corruption that happened inside the camera *before* offload.

---

### 3. [`scripts/Invoke-MacMetadataForensics.ps1`](./scripts/Invoke-MacMetadataForensics.ps1) (macOS `._*` AppleDouble Forensic Extractor & Cleaner)
- Parses `4,096-byte` macOS `._*` AppleDouble sidecar files (magic header `0x00051607`) created when an `exFAT` card is mounted on macOS (`com.apple.FinderInfo`, `com.apple.quarantine`, Spotlight strings).
- Extracts human-readable ASCII strings for forensic inspection (`mac_metadata_findings.txt`) and, when `-DeleteJunkAfterDump` is passed, purges Tier-2 OS clutter (`._*`, `.DS_Store`, `Thumbs.db`, `desktop.ini`) while strictly protecting Tier-1 creative sidecars (`.AAE`, `.XMP`, `.SRT`, `.CUBE`).

---

### 4. [`scripts/Invoke-TDDTestSuite.ps1`](./scripts/Invoke-TDDTestSuite.ps1) (14-Invariant Red/Green TDD & Mutation Runner)
- Creates an isolated synthetic camera card inside `%TEMP%\OffloadPro_TDD_<GUID>` (never touching your real drives), seeds synthetic PDFs, Live Photo pairs (`.JPG` + `.MOV`), later-edited `.AAE` sidecars, orphan `.XMP` sidecars, Sony `M4ROOT\CLIP` trees, and `._*` AppleDouble files, and verifies **14 invariants** (including flipping 1 bit of a sealed file to prove `VerifyMhl` catches it with `ExitCode == 1`, `HealFromMirror` heals it back to `7/7 Verified OK`, `FakeFormatCard`/`RestoreCard` reversible 2 MiB round-trip header inversion, and `GenerateProxies` renders 1-click NLE proxy files) in ~3 seconds before deleting the temp directory in `finally`.

---

## Part 3: Frequently Asked Questions (FAQ)

### Q1: Why is a checksum copy (Level 1) not enough on its own? Why do I need Levels 2 and 3?
**A:** A cryptographic checksum (`SHA-256` or `MD5`) only proves that **Destination (`E:\`) equals Source (`D:\`)**. If your camera's battery died mid-recording or the SD card had a bad NAND block while shooting, the corrupt `.MOV` on `D:\` will copy to `E:\` with a **100% matching SHA-256 hash**!
- **Level 1** proves the *copy* was bit-for-bit identical.
- **Level 2 (`ffprobe`)** proves the *container and `moov` index table* are valid.
- **Level 3 (`ffmpeg` decode)** proves the *actual video/audio streams* can be decoded end-to-end without bitstream errors.

### Q2: Why does my SD card show thousands of `4 KB` `._*` files after plugging it into a Mac? Are they safe to delete?
**A:** Because `exFAT` and `FAT32` do not support native macOS Extended Attributes (xattrs), macOS creates a hidden `4,096-byte` AppleDouble file (`._IMG_0001.MOV`) alongside every real file. Worse, on a `128 KB` `exFAT` allocation unit, each `4 KB` `._*` file consumes a full `128 KB` cluster (`124 KB` of slack waste per file).
- **Tier-2 OS Clutter (`._*`, `.DS_Store`, `Thumbs.db`):** 100% safe to isolate (`-MacMode forensic_split`) or skip (`-MacMode clean`).
- **Tier-1 Creative Sidecars (`.AAE`, `.XMP`, `.SRT`, `.CUBE`, `.XML`, `.BIM`, `.CPI`):** **NEVER delete these.** They contain your iOS non-destructive photo edits, Lightroom grades, DJI drone GPS telemetry, and Sony/Canon camera metadata. OffloadPro automatically protects Tier-1 sidecars in all modes.

### Q3: Why does OffloadPro warn against formatting an SD card in Windows (`format D: /FS:exFAT /Q`) if the card is going back into a camera?
**A:** High-bitrate cameras (Sony FX3/A7S III, RED, Blackmagic, Canon R5, DJI Mavic) expect specific **Allocation Unit (AU) cluster alignments**, CBR fat-table layouts, and OEM root folders (`PRIVATE\M4ROOT`, `DCIM`, `MISC`). Formatting in Windows writes generic PC cluster geometry, which can cause **dropped frames or buffer-overrun recording stops** on set.
- **Going back into a camera/drone?** Always format using the **Camera's built-in Format Menu** (only *after* verifying 3-2-1 backups).
- **Reusing as a PC thumb drive?** Use `format D: /FS:exFAT /Q` (2-second quick bitmap reset).
- **Selling or lending the card to a stranger?** Use `format D: /FS:exFAT /P:1` (overwrites 100% of sectors with zeros so old photos/videos cannot be carved with PhotoRec/Recuva).

### Q4: How does [`public/index.html`](./public/index.html) work offline (`file://`) without Node.js or a local web server?
**A:** Modern browsers block `fetch()` requests on `file://` URLs due to CORS rules, which is why most tools force you to run a local Node/Python server. OffloadPro bypasses `file://` CORS cleanly using two native mechanisms:
1. **Static `<script src="offloadpro-telemetry.js">` Data Bus:** `<script>` tags are exempt from `file://` CORS restrictions, allowing PowerShell (`-Action ExportTelemetry`) to publish hardware volume and preflight telemetry into `window.__OFFLOADPRO_TELEMETRY__`.
2. **Browser-Native `<input type="file" webkitdirectory>` + WebCrypto API (`crypto.subtle.digest`):** Lets you select any local folder or `.mhl` XML file directly in the browser to compute ECDF statistics, 5-second Source vs. Backup parity diffs, and SHA-256 Merkle roots 100% client-side in RAM.

### Q5: How do I import the `.ALE` file into DaVinci Resolve or Avid Media Composer?
**A:** Every offload generates `<BackupName>.ale` alongside `<BackupName>.mhl`.
- In **DaVinci Resolve**: Open the **Media Pool**, right-click your bin -> **Import** -> **Tracks / ALE...** (or **Import Media from ALE**) and select `<BackupName>.ale`. All clip names, byte sizes, `SHA256` checksums, and roll IDs (`Tape`) populate directly in your bin columns.

### Q6: How do I attach OffloadPro proxies in DaVinci Resolve or Premiere Pro?
**A:** Because `-Action GenerateProxies` preserves the identical relative directory structure and clip base name (e.g. `PRIVATE\M4ROOT\CLIP\C0001.mp4`), relinking is 100% automated:
- **In DaVinci Resolve:** Select your master clips in the Media Pool -> right-click -> **Proxy Media** -> **Relink Proxy Media...** -> select the `<RollName>_Proxies` folder.
- **In Premiere Pro:** Select clips -> right-click -> **Proxy** -> **Attach Proxies...** -> select `<RollName>_Proxies`. Premiere matches all audio tracks and timecode automatically.

### Q7: How does Reversible Safe Card Release work, and why does it beat Mac-only tools like o/PARASHOOT?
**A:** Tools like o/PARASHOOT blindly check only file name and size before flipping card bits, which can lead to data loss if an offload was truncated or corrupted during copy. OffloadPro adds a **mandatory Cryptographic Parity Gate** before touching the card. It inverts the first 2 MiB of the partition header (`XOR 0xFF`), rendering it unreadable to OS file systems and forcing the camera to prompt for in-camera formatting. If an emergency arises, `-Action RestoreCard` inverts the bits back in 1 second, restoring 100% of the partition and clips without re-formatting.
