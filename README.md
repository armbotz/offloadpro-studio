# OffloadPro DIT Studio v4.4.0

**Professional Open-Source Media Offload & DIT Archival Engine for Windows (PowerShell 5.1 & 7+).**  
Single-read multi-destination inline checksumming, crash-resumable checkpointing, native **ASC-MHL v2 (`ascmhl/`)** and legacy MHL v1.1 sealing, DaVinci Resolve & Avid `.ALE` generation, self-healing 3-2-1 vault repair, Win32 hardware-locked card release, and zero-server static HTML UI.

```text
100% Zero Node.js | Zero npm Bloat | Zero Localhost Server | Pure Native .NET Standard
```

<p align="center">
  <img src="docs/screenshots/offloadpro-studio-overview.jpg" alt="OffloadPro DIT Studio Main Interface" width="100%">
  <br>
  <em>OffloadPro DIT Studio 3-Column Mission Control: Hardware Volume Bay & S.M.A.R.T. Health, Single-Read Offload Engine, and Standalone Verification Dock.</em>
</p>

---

## Quickstart: Native PowerShell Module

OffloadPro is packaged as a standard PowerShell module. No compilation or administrative installation required:

```powershell
# Import the module
Import-Module .\modules\OffloadPro\OffloadPro.psd1 -Force

# 1. Dual-Destination Ingest with Inline SHA-256, ASC-MHL v2 & DaVinci Resolve .ALE
Start-OffloadProSession `
    -SourceRoot "D:\" `
    -DestinationRoot "E:\Backups\Roll_A001" `
    -SecondaryDestinationRoot "F:\Backups\Roll_A001" `
    -CameraId "CamA" -RollId "A001" `
    -Algorithm "SHA256"

# 2. Check Cryptographic Parity Between Source Card and Backup
Test-MediaParity -ArchiveA "D:\" -ArchiveB "E:\Backups\Roll_A001"

# 3. Long-Term Bitrot Scrubbing Against ASC-MHL Ledger
Test-MediaArchive -ArchivePath "E:\Backups\Roll_A001"

# 4. Self-Healing Bitrot Repair from Mirror Drive
Repair-MediaVault -PrimaryArchivePath "E:\Backups\Roll_A001" -MirrorArchivePath "F:\Backups\Roll_A001"

# 5. Reversible Safe Card Release (Locked to Physical Removable Drives)
Clear-CameraCard -CardPath "D:\" -VerifiedBackupPath "E:\Backups\Roll_A001"
Undo-CardClear -CardPath "D:\"
```

---

## Visual Feature Walkthrough & How-To Field Guide

OffloadPro DIT Studio bridges the gap between Hollywood on-set safety protocols and open-source systems programming. Here is how the complete ingest-to-vault lifecycle works:

```text
[ Camera Card (D:\) ]
         │
         ├───► 1. Pre-Flight X-Ray & S.M.A.R.T. (Detect gaps, slack, card health)
         │
         ▼
[ Single-Read In RAM ] ────► SHA-256 Checksum Computed In-Memory (Zero Double-Read)
         │
         ├──────────────────────────────┬──────────────────────────────┐
         ▼                              ▼                              ▼
 [ Primary NVMe (E:\) ]        [ Mirror Drive (F:\) ]        [ ASC-MHL v2 & .ALE ]
 (FlushFileBuffers HW Lock)    (Simultaneous 3-2-1 Copy)     (Chained XML Ledger)
         │
         ├───► 3-Level Audit (Level 1 Hash + Level 2 Container + Level 3 Frame Decode)
         │
         ├───► 5-Second In-Browser Parity Diff (WebCrypto Merkle Tree)
         │
         ▼
 [ Reversible Card Release ] ──► Safe to hand back to camera department!
```

### Stage 1: 1-Click Launch & Zero-Server Ambient HUD
Double-click [`Start-OffloadPro-Studio.bat`](./Start-OffloadPro-Studio.bat). OffloadPro opens immediately in your default browser using the native `file://` protocol. 
- **Zero Background Daemons:** No Node.js runtime, Python web servers, or open localhost ports.
- **10-Foot Ambient Status Halo:** Glance from across the DIT cart — the browser window perimeter turns **Green** (100% verified parity), **Amber** (in progress), or **Red** (rot/checksum mismatch).
- **Web Audio DIT Chimes:** Built-in synthesis generates Hollywood-standard audible completion chimes without loading external audio assets.

### Stage 2: Hardware Bay & Pre-Flight Card Diagnostics
Insert the camera card (`D:\`). OffloadPro inspects the storage medium before moving a single byte:

<p align="center">
  <img src="docs/screenshots/offloadpro-xray-telemetry.jpg" alt="Pre-Flight Card Diagnostics and X-Ray" width="65%">
  <br>
  <em>Pre-Flight X-Ray: Hardware S.M.A.R.T. health, cluster slack overhead, AppleDouble (._*) forensic sidecars, and ThinkStats2 ECDF Pareto file distribution.</em>
</p>

- **S.M.A.R.T. Bus & SD Lock Tab Detection:** Confirms device physical health and flags if the physical SD write-protect tab is unlocked.
- **exFAT 128 KB Cluster Slack Waste:** Computes exact disk sector overhead wasted by millions of small files.
- **Sequence Gap & Orphan Sidecar Detector:** Scans clip patterns (`C0001`, `C0002`, `C0004`) to warn if a clip was skipped or deleted in-camera, and pairs `.AAE` / `.XMP` sidecars to their master footage.
- **ThinkStats2 ECDF Pareto Skew:** Visualizes file size distributions and computes Pareto concentration (e.g. top 10% largest video files hold 85% of total payload).

### Stage 3: ShotPut Pro-Style Single-Read Multi-Destination Ingest
Configure your ingest directly in the UI dock or via native PowerShell:
- **Single-Read In RAM:** Reads each 4 MB block from the SD card exactly once via `.NET` `[System.IO.FileStream]` with `SequentialScan` optimization.
- **Parallel Streaming to 2+ Drives:** Writes simultaneously to Primary NVMe (`E:\`) and Secondary Backup (`F:\`) to satisfy the 3-2-1 backup rule in half the offload time.
- **Hardware Buffer Flushing:** Calls Win32 `FlushFileBuffers` (`$fs.Flush($true)`) to ensure bytes are committed to physical NAND flash before completing.
- **Crash-Resumable Checkpoints:** Interrupted by a loose cable? Re-run the command; existing intact files matching byte length and UTC timestamp are verified in-place (`Resumed: N`) with zero re-reads.

### Stage 4: 3-Level Verification Pipeline & Rescue Profile
Choose the verification rigor appropriate for your turn-around schedule:
- **Level 1 (Cryptographic Hash):** Bit-for-bit SHA-256 or MD5 verification proving zero transmission bits flipped.
- **Level 2 (Container & moov Atom Integrity):** `ffprobe` scans container headers and moov index atoms to ensure camera power was not cut mid-take.
- **Level 3 (Deep Frame-by-Frame Decode):** Full `ffmpeg` stream decode demuxes all audio/video frames into a null sink to catch mid-stream flash cell rot.
- **Dying Card Rescue Mode:** Automatically prioritizes small, critical files first (audio takes, LUTs, EDL/ALE metadata) before streaming large video takes on failing media.

### Stage 5: ASC-MHL v2 & DaVinci Resolve `.ALE` Production Sealing
Upon transfer completion, OffloadPro automatically writes an immutable chain of custody:
- **`ascmhl/ascmhl_chain.xml`:** American Society of Cinematographers MHL v2 standard ledger chaining generational manifests with ISO 8601 UTC timestamps.
- **`<RollName>.mhl`:** Legacy v1.1 XML format for Silverstack and legacy tools.
- **`<RollName>.ale`:** Tab-delimited Avid Log Exchange manifest ready for 1-click conform in DaVinci Resolve and Avid Media Composer.
- **Turnover CSV & HTML Certificate:** Printable, self-contained verification report with hardware drive serial numbers and audit proofs for production insurers.

### Stage 6: 5-Second In-Browser "Safe-to-Pull Card" Parity Diff
Before formatting or releasing the camera card:
- Select the Source Card (`D:\`) and Backup Vault (`E:\`) in the browser UI.
- The client-side WebCrypto engine filters OS clutter (`._*`, `.Spotlight-V100`, `.Trashes`), computes a SHA-256 Tree Structure Merkle Root over sorted `relativePath:byteLength` descriptors in browser memory, and verifies `0 missing clips` and `0 byte-size delta` in under 5 seconds (complementing the Level 1 PowerShell bit-for-bit content hash).
- Gives the DIT immediate green visual clearance to clear the card.

### Stage 7: Reversible Safe Card Release
When clearing camera cards for re-use:
- **Shift-Left Hardware Lock:** Win32 raw header inversion (`Clear-CameraCard`) is locked to physical `Removable` media; internal SSDs and network shares are rejected even with `-Force`.
- **1-Click Undo Recovery (`XOR 0xFF` Header Inversion):** Reversibly inverts the first `2 MiB` partition/boot header (saving an emergency `.bin` header backup) so the camera prompts to format, while `Undo-CardClear` can restore the partition table before the card is overwritten in-camera.

### Stage 8: Long-Term Bitrot Scrubbing & Self-Healing Mirror Repair
Keep archive vaults healthy over months and years:
- **Bitrot Scrubbing (`Test-MediaArchive`):** Runs multi-threaded verification of all stored files against the sealed `ascmhl/` ledger.
- **Self-Healing Mirror Repair (`Repair-MediaVault`):** If a corrupted clip is detected on your primary vault, OffloadPro queries your secondary 3-2-1 mirror, verifies the mirror's hash, and hot-swaps the corrupt clip with zero human intervention.

---

## Industry Production Standards Supported

| Deliverable | Standard / Format | Target Users | Role & Guarantee |
| :--- | :--- | :--- | :--- |
| **ASC-MHL v2** | `ascmhl/ascmhl_chain.xml` | Post Houses, Studios, DITs | **Cryptographic Chain of Custody:** The official American Society of Cinematographers XML format. Chains generational manifests with strict ISO 8601 UTC timestamps. |
| **Legacy MHL** | `<RollName>.mhl` (v1.1 XML) | Silverstack v4, ShotPut Pro | **Backward Compatibility:** Single-file `<hashlist>` verifying 100% full-roll checksums on legacy archival tools. |
| **Avid Log Exchange** | `<RollName>.ale` | DaVinci Resolve, Avid Media Composer | **Instant NLE Ingest:** Tab-delimited metadata linking tape name, clip name, duration, and checksum for 1-click conform. |
| **Turn-Over Manifest** | `<RollName>_PostHouse_Manifest.csv` | Post Supervisors, Lab, Production | Spreadsheet summary of all captured media, relative paths, byte counts, and hashes. |
| **Offload Certificate** | `<RollName>_Offload_Certificate.html` | Producers, Completion Guarantors | Printable, self-contained verification report with hardware serial numbers and base64 keyframe contact sheets. |

---

## Built for 4 Core Personas

| Persona | Key Workflows in OffloadPro |
| :--- | :--- |
| **🎬 On-Set DITs & Digital Loaders** | Single-read dual-destination streaming (`SequentialScan` + `FlushFileBuffers`), **ASC-MHL v2 (`ascmhl/`)** + `.ALE` deliverables, tokenized folder naming (`-CameraId` / `-RollId`), **Crash-Resumable Checkpointing** (0 re-reads of intact clips after power interruption), and **Reversible Safe Card Release** (`Clear-CameraCard`). |
| **📷 Hybrid Shooters & Drone Pilots** | Protection of Tier-1 creative sidecars (`.AAE` iOS edits, `.XMP` Lightroom metadata, `.SRT` DJI drone logs, `.CUBE` LUTs) and **`-Action OrganizeByDate`** (`YYYY\YYYY-MM-DD`) that glues Live Photos and edited sidecars to their parent capture date. |
| **🗄️ `/r/DataHoarder` & Archival Vaults** | **Self-Healing 3-2-1 Vault Repair (`Repair-MediaVault`)**, **Two-Stage O(1) Size + Multi-Threaded Hash Deduplication (`Find-DuplicateMedia`)**, and cross-archive Merkle parity comparator (`Test-MediaParity`). |
| **🧪 DevSecOps & Enterprise IT** | **Zero Node.js / Zero Server** attack surface, **Shift-Left Removable Hardware Locks** (`Removable` media enforcement, UNC path blocking, Win32 `DeviceIoControl` return validation), Zero-PII console invariant, and a 14-test deterministic regression suite. |

---

## Shift-Left Security & Hardware Safety

1. **Removable Media Hardware Lock (`Clear-CameraCard`):** Raw sector writes (`\\.\X:`) are hard-locked to require `DriveType.Removable`. Targeting `Fixed` (internal SSDs), `Network` (SAN/NAS), or `RAMDisk` drives is strictly blocked even with `-Force`.
2. **Network UNC Path Block:** Any target path starting with network shares (`\\server\share`) is blocked immediately.
3. **Win32 Kernel Volume Locking:** Validates return codes from `kernel32!DeviceIoControl` (`FSCTL_LOCK_VOLUME`, `FSCTL_DISMOUNT_VOLUME`, `FSCTL_UNLOCK_VOLUME`), aborting safely if any process holds an active file handle.
4. **Ledger Anti-Contamination:** Directory walkers strictly ignore `ascmhl/`, `*.mhl`, `*.ale`, `*.csv`, and `*.html` so resumed offloads never re-hash existing manifests into new generations.
5. **Zero-PII Invariant:** All console logging outputs only aggregate counters; no personal filenames or shoot directories are ever written to `stdout`.

---

## Automated Verification & Regression Gates

Verify all 14 architectural invariants (camera OEM recognition, full-roll ASC-MHL sealing, 1-bit mutation detection, self-healing mirror repair, crash-resumable checkpoints, roll-collision safety, and zero-PII privacy) in 3 seconds:

```powershell
# 1. Run the 14-Invariant TDD & Mutation Suite
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-TDDTestSuite.ps1

# 2. Run the Maya Lin On-Set Feature Film Production Demo
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-PersonaDemo.ps1
```

---

## Key Features

### 1. Single-Read Multi-Destination Inline Hash Engine & Cart Safety Gates
- **Pre-Flight Cart Safety Gates:**
  - **5% Free-Space Headroom Gate:** Blocks transfers upfront if any destination drive lacks the required byte payload plus a 5% NTFS safety headroom buffer.
  - **Roll-Name Collision Guard:** Detects if a destination folder already contains files with identical relative paths but different byte sizes (preventing accidental mixing of Roll A001 and Roll A002).
- **Single-Read Multi-Destination Streaming:** Reads each 4 MB chunk from the source SD card **only once** into RAM via native `.NET` `[System.IO.FileStream]`, computing cryptographic hashes (`SHA-256`, `MD5`, or `SHA-1`) while simultaneously writing to **primary and secondary backup drives**.
- **Zero-Re-Read Full-Roll `.mhl` Sealing:** Immediately writes the 100% full-roll `<BackupName>.mhl` XML manifest at the end of the offload using the inline hashes already computed in RAM.

### 2. 3-Level Media & Bit-for-Bit Verification Pipeline + Long-Term `.mhl` Bitrot Scrubbing
| Level | Verification Layer | What It Proves |
| :--- | :--- | :--- |
| **Level 1** | **Bit-for-Bit Cryptographic Hash (`SHA-256` / `MD5`)** | 100% mathematical certainty (codec-agnostic) that zero bits flipped between Source (`D:\`) and Destination (`E:\`). |
| **Level 2** | **`ffprobe` Container, `moov` Atom & Codec Header Scan** | Verifies that no `.MOV` / `.MP4` was truncated during recording (validates the `moov` index table at the end of the file and decodes initial `SPS/PPS` keyframes), plus checks JPEG, Audio, and `%PDF-` headers. |
| **Level 3** | **`ffmpeg` Deep End-to-End Stream & Frame Decode** | Demuxes 100% of every media file from byte `0` to the end and decodes video keyframes, all audio frames, and all photos into a null sink (`-f null -`) to catch mid-stream flash sector bitrot. |
| **Vault Scrub** | **`-Action VerifyMhl` Multi-Threaded Bitrot Verifier** | Re-verifies 100% of an archive drive against its sealed `.mhl` XML ledger across 6 threads months or years later to detect silent SSD/HDD sector decay. |

### 3. 5-Second "Safe to Pull Card" Parity Diff (`Source D:\` vs. `Backup E:\` in Browser)
- Select **Source (`D:\`)** and **Backup (`E:\`)** directly in [`public/index.html`](./public/index.html) (`webkitdirectory`).
- Automatically filters out Tier-2/Tier-3 OS clutter (`._*`, `.DS_Store`, `.Spotlight-V100`, `.Trashes`, `System Volume Information`), computes both `SHA-256` Tree Structure Merkle Roots client-side via WebCrypto, and verifies `0 missing clips` and `0 byte delta` in under 5 seconds — without printing a single personal filename.

### 4. Non-Destructive Sidecar-Glued Date Organizer (`-Action OrganizeByDate`)
- Organizes camera dumps into clean `YYYY\YYYY-MM-DD` folders (via copy or instant NTFS hardlinks `-UseHardlinks`).
- **Live-Photo & Edited Sidecar Gluing:** Determines each clip group's canonical capture date from the primary photo/video first, so `.AAE` edits or `.XMP` ratings modified months later stay in the exact same `YYYY\YYYY-MM-DD` folder as their parent `IMG_xxxx.JPG`/`.HEIC`/`.MOV`.

---

## Documentation Index

- **[Changelog (`CHANGELOG.md`)](./CHANGELOG.md):** Detailed version history and release notes.
- **[Operational Runbook (`RUNBOOK.md`)](./RUNBOOK.md):** Step-by-step GUI and standalone `robocopy` + PowerShell CLI instructions.
- **[System Architecture & Math (`ARCHITECTURE.md`)](./ARCHITECTURE.md):** Deep dive into the `file://` Static Data-Bus pattern, Single-Read `.NET` streaming, `exFAT` 128 KB block slack equations, and *ThinkStats2* ECDF / Bivariate ETA models.
- **[Security, Privacy & Safety Guardrails (`SECURITY_AND_PRIVACY.md`)](./SECURITY_AND_PRIVACY.md):** Zero-Node/Zero-Server architecture, Zero-Knowledge Merkle roots, and TDD privacy invariants.
- **[MIT License (`LICENSE`)](./LICENSE):** Permissive open-source license.

---

## Repository Structure

```text
offloadpro-studio/
├── .github/
│   └── workflows/
│       └── ci.yml                         # Windows CI/CD gate (Zero-Node check, AST linter, TDD suite & persona demo)
├── docs/
│   └── screenshots/                       # High-resolution production UI & forensic telemetry screenshots
├── modules/
│   └── OffloadPro/
│       ├── OffloadPro.psd1                # PowerShell Module Manifest (v4.4.0, PS 5.1 & Core compatible)
│       ├── OffloadPro.psm1                # Public cmdlets (Start-OffloadProSession, Test-MediaParity, etc.)
│       └── Private/                       # 21 modularized in-process engine components
├── public/
│   ├── index.html                         # Standalone offline static HTML Studio UI (file://, Halo & Web Audio)
│   └── offloadpro-telemetry.js            # Aggregate telemetry snapshot loaded offline by index.html
├── scripts/
│   ├── Invoke-OffloadProEngine.ps1        # Thin backward-compatible CLI bridge to the PowerShell module
│   ├── Invoke-3LevelAudit.ps1             # Multi-threaded PowerShell 3-Level Audit CLI (MD5 + FFprobe + FFmpeg Decode)
│   ├── Invoke-MacMetadataForensics.ps1    # macOS ._* AppleDouble string extractor & Tier-2 OS junk cleaner
│   ├── Invoke-TDDTestSuite.ps1            # 14-Invariant Red/Green TDD & Bit-Flip Mutation Test Runner
│   └── Invoke-PersonaDemo.ps1             # Maya Lin On-Set Feature Film Production Simulation Demo
├── ARCHITECTURE.md                        # Systems & mathematical architecture deep dive
├── CHANGELOG.md                           # Version history & release notes
├── SECURITY_AND_PRIVACY.md                # Zero-Server, Merkle privacy & cart safety documentation
├── RUNBOOK.md                             # Complete operational & CLI runbook / KB article
├── LICENSE                                # MIT Open-Source License
├── Start-OffloadPro-Studio.bat            # 1-Click offline HTML Studio launcher (zero server)
└── .gitignore                             # Git ignore rules
```
