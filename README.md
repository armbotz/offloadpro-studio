# OffloadPro DIT Studio v3.2 (Lead DIT & Enterprise DevSecOps Edition)

**ShotPut Pro & Silverstack-Style Media Offload Engine, Multi-Destination Inline Checksum Verifier, 100% Full-Roll Multi-Threaded ASC-MHL Sealer & Bitrot Verifier, 3-Level FFmpeg Stream Validator, and macOS Forensic Toolkit.**

OffloadPro DIT Studio v3.2 is a **100% Pure PowerShell (5.1 & 7+) + Standalone Offline Static HTML** application designed for bulletproof, one-shot archival offloads from large SD / CFexpress / USB media cards (`exFAT` / `FAT32`) to Windows storage volumes (`NTFS`) and Azure Blob Vaults — requiring **zero Node.js runtime, zero npm packages, and zero localhost HTTP servers**.

Unlike standard checksum-only offload tools that only verify whether a broken file on an SD card was copied identically, OffloadPro combines **3 distinct verification layers** with **100% Full-Roll ASC-MHL sealing**, **5-Second Source vs. Backup Merkle Parity Diff**, **macOS extended attribute (`._*` & `.Spotlight-V100`) forensics**, and **ThinkStats2 ECDF / SHA-256 Merkle telemetry**.

---

## Key Features

### 1. Single-Read Multi-Destination Inline Hash Engine & Cart Safety Gates (Pure PowerShell / .NET)
- **Pre-Flight Cart Safety Gates:**
  - **5% Free-Space Headroom Gate:** Blocks transfers upfront if any destination drive lacks the required byte payload plus a 5% (minimum `2 GB`) NTFS safety headroom buffer.
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
- Select **Source (`D:\`)** and **Backup (`E:\`)** directly in `public/index.html` (`webkitdirectory`).
- Automatically filters out Tier-2/Tier-3 OS clutter (`._*`, `.DS_Store`, `.Spotlight-V100`, `.Trashes`, `System Volume Information`), computes both `SHA-256` Tree Structure Merkle Roots client-side via WebCrypto, and verifies `0 missing clips` and `0 byte delta` in under 5 seconds — without printing a single personal filename.

### 4. Hardware Volume Bay, S.M.A.R.T. Telemetry, Write-Protect Lock & `exFAT` Block-Slack X-Ray
- Auto-detects all mounted Windows drives (`Get-Volume` + `Get-PhysicalDisk`), displaying capacity bars, filesystem type (`exFAT` vs. `NTFS`), hardware allocation unit (cluster) sizes (`128 KB blocks` vs. `4 KB blocks`), Volume Serial Number, and S.M.A.R.T. HealthStatus (`Healthy` / `Warning` / `Unhealthy`).
- Detects whether the physical SD card Write-Protect Lock switch is **LOCKED (`Read-Only`)** or **UNLOCKED (`Writable`)**.
- Calculates exact **exFAT 128 KB cluster slack waste** caused by thousands of 4 KB macOS `._*` AppleDouble companion files.
- Computes **ThinkStats2 ECDF Quantiles (`P50`, `Mean`, `P90`, `P99`, `Max`)**, Pareto Top-10% byte concentration, Bivariate ETA (`T(N, B)`), and a **SHA-256 Tree Structure Merkle Root**.

### 5. Silverstack-Style HTML Certificate (`HH:MM:SS` Total Duration, Codec Profiles & Base64 Contact Sheet)
- Generates a multi-threaded **100% Full-Roll ASC-MHL (`.mhl`)** XML manifest and a dark-mode printable **Camera Roll Verification Certificate (`_Offload_Certificate.html`)** featuring:
  - Total playable footage duration (`HH:MM:SS`) and capture date window (`YYYY-MM-DD to YYYY-MM-DD`).
  - Camera codec & resolution breakdown (`HEVC 3840x2160`, `H264 1920x1080`, etc.) via multi-threaded `ffprobe`.
  - Up to 12 embedded base64 JPEG video keyframes extracted in-memory via `ffmpeg` (100% offline, zero personal filenames exposed).

---

## Repository Structure

```text
offloadpro-studio/
├── .github/
│   └── workflows/
│       └── ci.yml                         # Windows CI/CD gate (Zero-Node check, AST linter & E2E bitrot test)
├── public/
│   ├── index.html                         # Standalone offline static HTML Studio UI (file:// ready, zero server)
│   └── offloadpro-telemetry.js            # Aggregate telemetry snapshot loaded offline by index.html
├── scripts/
│   ├── Invoke-OffloadProEngine.ps1        # Master PowerShell 5.1/7+ engine (Preflight, Offload, Full-Roll MHL, VerifyMhl)
│   ├── Invoke-3LevelAudit.ps1             # Multi-threaded PowerShell 3-Level Audit CLI (MD5 + FFprobe + FFmpeg Decode)
│   └── Invoke-MacMetadataForensics.ps1    # macOS ._* AppleDouble string extractor & Tier-2 OS junk cleaner
├── Start-OffloadPro-Studio.bat            # 1-Click offline HTML Studio launcher (zero server)
├── RUNBOOK.md                             # Complete operational & CLI runbook / KB article
└── .gitignore                             # Git ignore rules
```
