# OffloadPro DIT Studio v3.0

**ShotPut Pro-Style Media Offload Engine, Multi-Destination Inline Checksum Verifier, 3-Level FFmpeg Stream Validator, ASC-MHL Generator & macOS Forensic Toolkit.**

OffloadPro DIT Studio v3.0 is a **100% Pure PowerShell + Standalone Offline Static HTML** application designed for bulletproof, one-shot archival offloads from large SD / CFexpress / USB media cards (`exFAT` / `FAT32`) to Windows storage volumes (`NTFS`) — requiring **zero Node.js runtime, zero npm packages, and zero localhost HTTP servers**.

Unlike standard checksum-only offload tools that only verify whether a broken file on an SD card was copied identically, OffloadPro combines **3 distinct verification layers** with **macOS extended attribute (`._*` & `.Spotlight-V100`) forensics** and **ThinkStats2 ECDF / SHA-256 Merkle telemetry**.

---

## Key Features

### 1. Single-Read Multi-Destination Inline Hash Engine (Pure PowerShell / .NET)
- Reads each 4 MB chunk from the source SD card **only once** into RAM via native `.NET` `[System.IO.FileStream]`.
- Computes cryptographic hashes (`SHA-256`, `MD5`, or `SHA-1`) in memory while simultaneously writing to **primary and secondary backup drives**.
- Performs a destination readback pass to guarantee zero bit-rot or bus corruption during the write phase, cutting total offload + verification time nearly in half compared to two-pass copying.
- Preserves original file and directory creation/modification timestamps (`CreationTimeUtc` / `LastWriteTimeUtc`).

### 2. 3-Level Media & Bit-for-Bit Verification Pipeline
| Level | Verification Layer | What It Proves |
| :--- | :--- | :--- |
| **Level 1** | **Bit-for-Bit Cryptographic Hash (`SHA-256` / `MD5`)** | 100% mathematical certainty (codec-agnostic) that zero bits flipped between Source (`D:\`) and Destination (`E:\`). |
| **Level 2** | **`ffprobe` Container, `moov` Atom & Codec Header Scan** | Verifies that no `.MOV` / `.MP4` was truncated during recording (validates the `moov` index table at the end of the file and decodes initial `SPS/PPS` keyframes), plus checks JPEG, Audio, and `%PDF-` headers. |
| **Level 3** | **`ffmpeg` Deep End-to-End Stream & Frame Decode** | Demuxes 100% of every media file from byte `0` to the end and decodes video keyframes, all audio frames, and all photos into a null sink (`-f null -`) to catch mid-stream flash sector bitrot. |

### 3. Hardware Volume Bay, S.M.A.R.T. Telemetry, Write-Protect Lock & `exFAT` Block-Slack X-Ray
- Auto-detects all mounted Windows drives (`Get-Volume` + `Get-PhysicalDisk`), displaying capacity bars, filesystem type (`exFAT` vs. `NTFS`), hardware allocation unit (cluster) sizes (`128 KB blocks` vs. `4 KB blocks`), Volume Serial Number, and S.M.A.R.T. HealthStatus (`Healthy` / `Warning` / `Unhealthy`).
- Detects whether the physical SD card Write-Protect Lock switch is **LOCKED (`Read-Only`)** or **UNLOCKED (`Writable`)**.
- Calculates exact **exFAT 128 KB cluster slack waste** caused by thousands of 4 KB macOS `._*` AppleDouble companion files.
- Computes **ThinkStats2 ECDF Quantiles (`P50`, `Mean`, `P90`, `P99`, `Max`)**, Pareto Top-10% byte concentration, Bivariate ETA (`T(N, B)`), and a **SHA-256 Tree Structure Merkle Root** — both in PowerShell and directly inside the browser via HTML5 folder selection (`webkitdirectory` + WebCrypto).

### 4. 3-Tier Sidecar Taxonomy, Gap Detection & Dying Card Rescue Mode
- **Tier 1 (Protected Creative Sidecars — NEVER Deleted):** Automatically protects `.AAE` (iOS photo edits), `.XMP` (Lightroom/Camera Raw metadata), `.SRT` (DJI drone GPS/telemetry), `.XML` (Sony/Canon camera metadata), `.CPI`/`.MPL` (AVCHD clip info), `.LRV`/`.THM`, and `.CUBE`/`.3DL` (3D LUTs).
- **Tier 2 (OS Clutter — Safe to Clean):** Targets only `._*` (`4,096 B` AppleDouble headers), `.DS_Store`, `Thumbs.db`, and `desktop.ini`.
- **Tier 3 (System / Forensic Directories):** Isolates `.Spotlight-V100`, `.Trashes`, `.fseventsd`, and `System Volume Information`.
- **Dying Card Rescue Mode (Smallest-First):** Sorts the copy queue ascending by file size so the median 50% of files are rescued before multi-hundred-MB 4K clips stress failing flash cells.

### 5. 3-State DIT Traffic Light, Offline Base64 Contact Sheet & Format Advisor
- Generates an XML Media Hash List (`.mhl`) manifest alongside the backup for long-term archival verification.
- Produces a dark-mode printable **DIT Offload & Verification Certificate (`_Offload_Certificate.html`)** with up to 12 embedded base64 JPEG video keyframes extracted locally in memory via `ffmpeg` (100% offline, zero cloud uploads, zero personal filenames printed to console).
- Enforces a **3-State DIT Traffic Light (`DO NOT FORMAT` -> `SINGLE COPY VERIFIED (1 OF 2)` -> `3-2-1 VERIFIED — SAFE TO FORMAT IN-CAMERA`)** and includes an **In-Camera vs. Windows Quick vs. OPSEC Format Advisor**.

---

## Repository Structure

```text
offloadpro-studio/
├── public/
│   ├── index.html                         # Standalone offline static HTML Studio UI (file:// ready, zero server)
│   └── offloadpro-telemetry.js            # Aggregate telemetry snapshot loaded offline by index.html
├── scripts/
│   ├── Invoke-OffloadProEngine.ps1        # Master PowerShell engine (Preflight, Single-Read Offload, MHL & Certificate)
│   ├── Invoke-3LevelAudit.ps1             # Multi-threaded PowerShell 3-Level Audit CLI (MD5 + FFprobe + FFmpeg Decode)
│   └── Invoke-MacMetadataForensics.ps1    # macOS ._* AppleDouble string extractor & Tier-2 OS junk cleaner
├── Start-OffloadPro-Studio.bat            # 1-Click offline HTML Studio launcher (zero server)
├── RUNBOOK.md                             # Complete operational & CLI runbook / KB article
└── .gitignore                             # Git ignore rules
```

---

## Quick Start

### Prerequisites
- **Windows 10 / 11** with PowerShell 5.1+ or PowerShell 7+
- **FFmpeg & FFprobe** installed in `PATH`:
  ```powershell
  winget install Gyan.FFmpeg.Essentials
  ```

### Launching the Offline Static Studio UI
Double-click **`Start-OffloadPro-Studio.bat`** or open **`public\index.html`** directly in any browser (`file://`).
- Use **📂 Scan Folder in Browser** to run an instant client-side ECDF Quantile, Sidecar Taxonomy & WebCrypto SHA-256 Merkle X-Ray on any folder.
- Use the **Standalone PowerShell Command Dock** to copy and run any offload, audit, certificate, or forensic command in your own PowerShell terminal.
