# Changelog: OffloadPro DIT Studio

All notable changes to this project are documented in this file following the [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) format and [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [v4.4.0] - 2026-11-05 (Final Golden Master)

### Added
- **Official ASC-MHL v2 Specification Implementation:**
  - Automated generation of the standardized `ascmhl/` directory at the archive root.
  - Implemented `ascmhl/ascmhl_chain.xml` cryptographic chain ledger and generational manifest linking (`<ascmhl xmlns="urn:ASC:MHL:v2.0">`).
  - Retained dual-generation of legacy MHL v1.1 (`<hashlist>`) for complete backward compatibility with older post-house tools.
- **Native PowerShell Module Architecture:**
  - Packaged engine into `modules/OffloadPro/` with `OffloadPro.psd1` manifest and `OffloadPro.psm1` module.
  - Exported standard verb-noun cmdlets: `Start-OffloadProSession`, `Test-MediaParity`, `Repair-MediaVault`, `Test-MediaArchive`, `New-CameraProxy`, `Clear-CameraCard`, `Undo-CardClear`, `Get-CameraCardXRay`, `Find-DuplicateMedia`, and `Invoke-MediaOrganization`.
  - Modularized 21 private engine functions into `modules/OffloadPro/Private/` for zero-overhead in-process execution.
- **Shift-Left Security & Hardware Safety Locks (SEC-01 - SEC-03):**
  - Physical Removable Media Hardware Lock: `Clear-CameraCard` and `Undo-CardClear` hard-blocked on all non-removable drives (`Fixed`, `Network`, `RAMDisk`).
  - Strict UNC / Network Path Blacklist: Immediate rejection of network targets (`\\server\share`).
  - Win32 Kernel Volume Locking: Validates return codes from `kernel32!DeviceIoControl` (`FSCTL_LOCK_VOLUME`, `FSCTL_DISMOUNT_VOLUME`, `FSCTL_UNLOCK_VOLUME`), aborting safely if Explorer or background indexing services hold open file handles.
  - Manifest Anti-Contamination Guard: Universally blacklisted `ascmhl/`, `*.mhl`, `*.ale`, `*.csv`, and `*.html` across all directory walkers and offload resumes.
- **Maya Lin Synthetic Production Demo:**
  - Created `scripts/Invoke-PersonaDemo.ps1` simulating a live on-set feature film turnover covering dual-target ingest, power-loss crash recovery, bitrot self-healing, and card release.
- **10-Foot Ambient Status Halo & Web Audio DIT Soundscape:**
  - Viewport-perimeter glow in `public/index.html` reflecting live transfer parity.
  - Synthesized Web Audio API Hollywood DIT chimes (523 Hz + 659 Hz double ding on success, 146 Hz + 110 Hz warning buzz on error) with zero external audio assets.

### Changed
- Slimmed `scripts/Invoke-OffloadProEngine.ps1` from 1,774 lines down to a clean ~230-line backward-compatible CLI bridge.
- Enhanced CI/CD pipeline (`.github/workflows/ci.yml`) to validate AST syntax across all module and script files, running on both PowerShell 7+ and Windows PowerShell 5.1.

---

## [v4.3.0] - 2026-11-04

### Added
- **Reversible DIT Safe Card Release (`FakeFormatCard` / `RestoreCard`):** 2 MiB partition header inversion (XOR 0xFF) prompting clean in-camera format on return to camera assistants, with 1-second lossless restore.
- **Automated Editorial Proxies (`GenerateProxies`):** Companion 720p/1080p H.264 FastStart proxies mirroring master camera folder hierarchy with optional roll/clip burn-in.
- Expanded automated regression suite to 14 deterministic tests.

---

## [v4.2.0] - 2026-11-03

### Added
- **Post-House NLE Deliverables:** Automated generation of Avid Media Composer / DaVinci Resolve `.ALE` (Avid Log Exchange) and turn-over `.CSV` spreadsheets during offload.
- **ThinkStats2 Telemetry:** Empirical Cumulative Distribution Function (ECDF) quantile profiling (`P10` through `P99`) and bivariate throughput ETA modeling.

---

## [v4.1.0] - 2026-11-02

### Added
- **Self-Healing 3-2-1 Vault Repair (`HealFromMirror`):** Multi-threaded cold-storage bitrot scrubber that cross-verifies secondary backup drives against the MHL ledger and atomically restores damaged sectors.
- **Camera OEM Structure Recognizer:** Fingerprinting for ARRI, RED (`.R3D`), Sony Cine (`M4ROOT\CLIP`), Blackmagic RAW (`.BRAW`), Canon, DJI, and Apple iOS formats.
- **Two-Stage O(1) Archive Deduplication (`DedupeScan`):** Instant pre-filtering of unique file sizes with multi-threaded runspace hashing on collisions.

---

## [v4.0.0] - 2026-11-01

### Added
- **OS Kernel SequentialScan & FlushFileBuffers:** Replaced blind copying with native .NET single-read dual-write streaming (`FileOptions.SequentialScan` and Win32 `FlushFileBuffers`).
- **Crash-Resumable Checkpointing:** Idempotent offload resume verifying intact destination files without re-reading camera media.
- **Zero-PII stdout Invariant:** Guaranteed zero personal filenames or camera clip paths printed to console logs.

---

## [v3.0.0] - 2026-10-31

### Added
- Initial pure PowerShell (5.1 & 7+) and offline static HTML architecture rewrite, completely banning and eliminating all Node.js, npm, and localhost server dependencies.
