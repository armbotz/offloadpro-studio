# OffloadPro DIT Studio v4.1

**Open-Source ShotPut Pro & Silverstack-Style Media Offload Engine, Multi-Destination Inline Checksum Verifier, Kernel-Optimized `SequentialScan` + `FlushFileBuffers` Streamer, Idempotent Crash-Resumable Checkpointing, 100% Full-Roll Multi-Threaded ASC-MHL Sealer & NLE (`.ALE`/`.CSV`) Exporter, Self-Healing 3-2-1 Bitrot Repair (`-Action HealFromMirror`), Camera OEM Structure Recognizer, Two-Stage O(1) Deduplication Engine, 3-Level FFmpeg Stream Validator, Sidecar-Glued Date Organizer, and macOS Forensic Toolkit.**

> **Mission & Positioning Statement:**  
> **For** independent filmmakers, on-set Digital Imaging Technicians (DITs), hybrid camera/drone hobbyists, and `/r/DataHoarder` archivers **who** refuse to trust blind drag-and-drop copies with irreplaceable footage—or pay \$150–\$1,500/year for proprietary offload software—**OffloadPro DIT Studio** is a **100% open-source, zero-server, pure PowerShell (5.1 & 7+) + offline static HTML archival engine**.  
> **Unlike** basic checksum tools that only verify whether a corrupted file on an SD card was copied identically—or Node/Electron apps that expose background servers and `npm` bloat—**OffloadPro v4.1** combines **Single-Read Multi-Destination Inline Hashing (`SHA-256`/`MD5`)**, **OS Kernel `SequentialScan` + Hardware `FlushFileBuffers`**, **Idempotent Crash-Resumable Offloads**, **Self-Healing Bitrot Repair (`HealFromMirror`)**, **Camera-Vendor OEM Structure Recognition**, **100% Full-Roll ASC-MHL + Avid/Resolve `.ALE` & `.CSV` NLE Deliverables**, **Two-Stage O(1) Archive Deduplication**, **3-Level FFmpeg Stream & Keyframe Decoding**, **Sidecar-Glued Date Organization**, **macOS `._*` AppleDouble Forensics**, and **ThinkStats2 ECDF / SHA-256 Merkle Telemetry** in a zero-dependency native Windows toolkit.

---

## Built for 4 Core Open-Source Personas

| Persona | Core Workflow in OffloadPro v4.1 |
| :--- | :--- |
| **🎬 On-Set DITs & Indie Filmmakers** | Single-read dual-destination inline hashing (`SHA-256`/`MD5`), **Camera-Vendor OEM Auto-Detection & `MEDIAPRO.XML` Conform Guard**, **`-CameraId` / `-RollId` Tokenized Folder Naming**, **Idempotent Crash-Resumable Checkpointing**, **5% Free-Space & Roll-Collision Safety Gates**, **100% Full-Roll `.mhl` Sealing**, **Avid/DaVinci Resolve `.ALE` & Post-House `.CSV` Deliverables**, **Spanned-Clip & Sequence Gap Detection**, and printable Silverstack-style HTML Certificates. |
| **📷 Camera Hobbyists & Drone Pilots** | Explains `exFAT` `128 KB` vs. `NTFS` `4 KB` block slack waste, protects Tier-1 creative sidecars (`.AAE` iOS edits, `.XMP` Lightroom metadata, `.SRT` DJI drone logs, `.CUBE` LUTs), and provides **`-Action OrganizeByDate`** (`YYYY\YYYY-MM-DD`) that keeps Live Photo pairs (`.HEIC`/`.JPG` + `.MOV`) and edited `.AAE`/`.XMP` sidecars glued to their parent capture date. |
| **🗄️ `/r/DataHoarder` & Archival Data Nerds** | **Self-Healing 3-2-1 Vault Repair (`-Action HealFromMirror`)**, **Two-Stage O(1) Size + Runspace Cryptographic Deduplication (`-Action DedupeScan`)**, **ThinkStats2 ECDF Quantiles (`P10`–`P99`)**, Pareto Top-10% concentration, Bivariate ETA modeling, **`-Action VerifyMhl`** multi-threaded cold-storage bitrot scrubbing, **`-Action CompareArchives`** cross-drive Merkle parity analysis, and **AzCopy v10** 3-2-1 Azure Blob Archive commands. |
| **🧪 DevSecOps, Enterprise IT & TDD Contributors** | **Zero Node.js / Zero Server** (`file://` static data bus), **Strongly-Typed `-PassThru` `[PSCustomObject]` Pipeline Output**, OS kernel `FileOptions.SequentialScan` + `$os.Flush($true)` (`FlushFileBuffers`), native Win32 `SetThreadExecutionState` sleep lock, Windows Event Log integration, deterministic CI exit codes (`0`/`1`), and a 3-second **12-Invariant Local TDD & Bit-Flip Mutation Suite ([`scripts/Invoke-TDDTestSuite.ps1`](./scripts/Invoke-TDDTestSuite.ps1))**. |

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
│       └── ci.yml                         # Windows CI/CD gate (Zero-Node check, AST linter & 7-test TDD suite)
├── public/
│   ├── index.html                         # Standalone offline static HTML Studio UI (file:// ready, zero server)
│   └── offloadpro-telemetry.js            # Aggregate telemetry snapshot loaded offline by index.html
├── scripts/
│   ├── Invoke-OffloadProEngine.ps1        # Master PowerShell 5.1/7+ engine (Preflight, Offload, MHL, OrganizeByDate)
│   ├── Invoke-3LevelAudit.ps1             # Multi-threaded PowerShell 3-Level Audit CLI (MD5 + FFprobe + FFmpeg Decode)
│   ├── Invoke-MacMetadataForensics.ps1    # macOS ._* AppleDouble string extractor & Tier-2 OS junk cleaner
│   └── Invoke-TDDTestSuite.ps1            # 7-Invariant Red/Green TDD & Bit-Flip Mutation Test Runner
├── ARCHITECTURE.md                        # Systems & mathematical architecture deep dive
├── SECURITY_AND_PRIVACY.md                # Zero-Server, Merkle privacy & cart safety documentation
├── RUNBOOK.md                             # Complete operational & CLI runbook / KB article
├── LICENSE                                # MIT Open-Source License
├── Start-OffloadPro-Studio.bat            # 1-Click offline HTML Studio launcher (zero server)
└── .gitignore                             # Git ignore rules
```

---

## Running the Local 12-Invariant TDD & Mutation Test Suite

Verify all 12 invariants (camera OEM & sequence gap detection, 3-tier sidecar taxonomy, full-roll `.mhl` sealing, 1-bit corruption detection, self-healing mirror repair `HealFromMirror`, roll-collision blocking, sidecar-glued date organization, zero-PII `stdout`, crash-resumable checkpointing, two-stage `DedupeScan`, NLE `.ALE`/`.CSV` post-house deliverables, and Sony `MEDIAPRO.XML` conform guard) using strongly-typed `-PassThru` objects and zero regex in 3 seconds:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Invoke-TDDTestSuite.ps1
```
