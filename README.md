# OffloadPro DIT Studio

**ShotPut Pro-Style Media Offload Engine, Multi-Destination Inline Checksum Verifier, 3-Level FFmpeg Stream Validator, ASC-MHL Generator & macOS Forensic Toolkit.**

OffloadPro DIT Studio is a zero-dependency Node.js + PowerShell application designed for bulletproof, one-shot archival offloads from large SD / CFexpress / USB media cards (`exFAT` / `FAT32`) to Windows storage volumes (`NTFS`).

Unlike standard checksum-only offload tools that only verify whether a broken file on an SD card was copied identically, OffloadPro combines **3 distinct verification layers** with **macOS extended attribute (`._*` & `.Spotlight-V100`) forensics**.

---

## Key Features

### 1. Single-Read Multi-Destination Inline Hash Engine
- Reads each 4 MB chunk from the source SD card **only once** into RAM.
- Computes cryptographic hashes (`MD5`, `SHA-256`, or `SHA-1`) in memory while simultaneously writing to **primary and secondary backup drives**.
- Performs a destination readback pass to guarantee zero bit-rot or bus corruption during the write phase, cutting total offload + verification time nearly in half compared to two-pass copying.
- Preserves original file and directory creation/modification timestamps (`atime` / `mtime`).

### 2. 3-Level Media & Bit-for-Bit Verification Pipeline
| Level | Verification Layer | What It Proves |
| :--- | :--- | :--- |
| **Level 1** | **Bit-for-Bit Cryptographic Hash (`MD5` / `SHA-256`)** | 100% mathematical certainty (codec-agnostic) that zero bits flipped between Source (`D:\`) and Destination (`E:\`). |
| **Level 2** | **`ffprobe` Container, `moov` Atom & Codec Header Scan** | Verifies that no `.MOV` / `.MP4` was truncated during recording (validates the `moov` index table at the end of the file and decodes initial `SPS/PPS` keyframes), plus checks JPEG, Audio, and `%PDF-` headers. |
| **Level 3** | **`ffmpeg` Deep End-to-End Stream & Frame Decode** | Demuxes 100% of every media file from byte `0` to the end and decodes video keyframes, all audio frames, and all photos into a null sink (`-f null -`) to catch mid-stream flash sector bitrot. |

### 3. Hardware Volume Bay, S.M.A.R.T. Telemetry, Write-Protect Lock & `exFAT` Block-Slack X-Ray
- Auto-detects all mounted Windows drives (`Get-Volume` + `Get-PhysicalDisk`), displaying capacity bars, filesystem type (`exFAT` vs. `NTFS`), hardware allocation unit (cluster) sizes (`128 KB blocks` vs. `4 KB blocks`), Volume Serial Number, and S.M.A.R.T. HealthStatus (`Healthy` / `Warning` / `Unhealthy`).
- Detects whether the physical SD card Write-Protect Lock switch is **LOCKED (`Read-Only`)** or **UNLOCKED (`Writable`)**.
- Calculates exact **exFAT 128 KB cluster slack waste** caused by thousands of 4 KB macOS `._*` AppleDouble companion files.
- Flags drives containing hidden `.Spotlight-V100` databases or `.Trashes` folders.

### 4. 3-Tier Sidecar Taxonomy, Gap Detection & Dying Card Rescue Mode
- **Tier 1 (Protected Creative Sidecars — NEVER Deleted):** Automatically protects `.AAE` (iOS photo edits), `.XMP` (Lightroom/Camera Raw metadata), `.SRT` (DJI drone GPS/telemetry), `.XML` (Sony/Canon camera metadata), `.CPI`/`.MPL` (AVCHD clip info), `.LRV`/`.THM`, and `.CUBE`/`.3DL` (3D LUTs).
- **Tier 2 (OS Clutter — Safe to Clean):** Targets only `._*` (`4,096 B` AppleDouble headers), `.DS_Store`, `Thumbs.db`, and `desktop.ini`.
- **Tier 3 (System / Forensic Directories):** Isolates `.Spotlight-V100`, `.Trashes`, `.fseventsd`, and `System Volume Information`.
- **Sequence & Pairing Integrity:** Detects orphan Apple Live Photos (`IMG_xxxx.JPG`/`HEIC` + `.MOV`), spanned camera clip numbering gaps, and intra-card duplicate files, plus matches destination backups against prior `.mhl` hash ledgers.
- **Dying Card Rescue Mode (Smallest-First):** Sorts the copy queue ascending by file size so the median 50% of files (`<= 9.20 MB`) are rescued before multi-hundred-MB 4K clips stress failing flash cells.

### 5. 3-State DIT Traffic Light, Offline Base64 Contact Sheet & Format Advisor
- Generates an XML Media Hash List (`.mhl`) manifest alongside the backup for long-term archival verification.
- Produces a dark-mode printable **DIT Offload & Verification Certificate (`_Offload_Certificate.html`)** with up to 12 embedded base64 JPEG video keyframes extracted locally via `ffmpeg` (100% offline, zero cloud uploads).
- Enforces a **3-State DIT Traffic Light (`DO NOT FORMAT` -> `SINGLE COPY VERIFIED (1 OF 2)` -> `3-2-1 VERIFIED — SAFE TO FORMAT IN-CAMERA`)** and includes an **In-Camera vs. Windows Quick vs. OPSEC Format Advisor**.
- **Privacy Sanitization (`.offloadpro.local.json`):** Stores local volume paths and session history in an untracked `.offloadpro.local.json` file so zero personal paths or folder names ever enter Git history.

---

## Repository Structure

```text
offloadpro-studio/
├── server.js                              # Zero-dependency Node.js HTTP + SSE offload & audit engine
├── public/
│   └── index.html                         # Dark-mode DIT Studio Web UI (Live SSE dashboard)
├── scripts/
│   ├── Invoke-3LevelAudit.ps1             # Standalone multi-threaded PowerShell 3-Level Audit CLI
│   └── Invoke-MacMetadataForensics.ps1    # Standalone macOS ._* string extractor & cleanup CLI
├── Start-OffloadPro-Studio.bat            # 1-Click Windows launcher
├── RUNBOOK.md                             # Complete operational & CLI runbook / KB article
├── package.json                           # Project manifest
└── .gitignore                             # Git ignore rules
```

---

## Quick Start

### Prerequisites
- **Windows 10 / 11** with PowerShell 5.1+ or PowerShell 7+
- **Node.js** v18+ (tested on Node v25.9.0 — zero `npm install` packages required)
- **FFmpeg & FFprobe** installed in `PATH`:
  ```powershell
  winget install Gyan.FFmpeg.Essentials
  ```

### Launching the Web Studio UI
Double-click **`Start-OffloadPro-Studio.bat`** or run from a terminal:

```powershell
node server.js
```

Then open **http://localhost:4789** in your browser.

---

## REST & SSE API Reference

| Method | Endpoint | Description |
| :---: | :--- | :--- |
| `GET` | `/api/drives` | Lists mounted volumes, free/used space, cluster sizes (`128 KB` vs `4 KB`), and `.Spotlight-V100` / `.Trashes` flags. |
| `POST` | `/api/preflight` | Scans a target drive or directory and returns real media counts, `._*` counts, file extension breakdown, and `exFAT` cluster slack. |
| `POST` | `/api/jobs/start` | Starts a Single-Read Inline Hash multi-destination offload with configurable Level 1 / 2 / 3 verification. |
| `GET` | `/api/jobs` | Returns active and historical offload/audit jobs. |
| `GET` | `/api/events` | Server-Sent Events (SSE) stream pushing real-time progress, speed (`MB/s`), and log lines to the UI. |
| `POST` | `/api/certificate/generate` | Generates an ASC-MHL (`.mhl`) manifest and `_Offload_Certificate.html` for a backup directory. |
| `POST` | `/api/forensics/extract` | Extracts readable metadata strings from all `._*` AppleDouble files into `mac_metadata_findings.txt`. |
| `POST` | `/api/forensics/clean` | Runs a dry-run count or recursive deletion of all `._*` and `.DS_Store` files. |

---

## Operational Runbook & CLI Usage
See **[RUNBOOK.md](./RUNBOOK.md)** for the complete step-by-step Standard Operating Procedure (SOP), `robocopy` command reference, 3-level audit PowerShell commands, and macOS forensic recovery guide.
