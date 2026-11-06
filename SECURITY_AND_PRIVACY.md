# Security, Privacy & Data-Safety Guardrails (`OffloadPro DIT Studio v4.4`)

OffloadPro DIT Studio is architected from the ground up around **zero network exposure, zero personal data leakage, Shift-Left security, and deterministic hardware safety**.

---

## 1. Zero Node.js & Zero Localhost Server Attack Surface

- **No Background Daemons or Open Ports:** OffloadPro runs 100% as native PowerShell scripts (`scripts/*.ps1`), a signed PowerShell module (`modules/OffloadPro`), and a static offline HTML interface (`public/index.html`) opened directly via `file://`.
- **Zero `npm` Supply-Chain Exposure:** There is no `package.json`, no `node_modules`, and no third-party JavaScript libraries or CDNs.
- **GitHub Actions Enforcement (`.github/workflows/ci.yml`):** Every push and pull request runs an automated CI gate that fails immediately if `server.js`, `package.json`, `.offloadpro.local.json`, or any `.mhl` manifest is committed.

---

## 2. Zero-Knowledge Merkle Parity & Strict Path Privacy

Archival tools often leak sensitive shoot names, client folders, or personal filenames (`IMG_xxxx.JPG`) in console logs, screenshots, or Git commits.

OffloadPro enforces **Aggregate-Only Telemetry**:
1. **Zero Personal Filenames on `stdout`:** All PowerShell scripts output only aggregate counters (`Real Media Files`, `Hash Mismatches: 0`, `Corrupt Streams: 0`). This invariant is continuously verified by **Test 8** in [`scripts/Invoke-TDDTestSuite.ps1`](./scripts/Invoke-TDDTestSuite.ps1).
2. **Cryptographic Tree Parity Without Filename Exposure (`merkleStructureRoot`):** To prove two folders have identical relative paths and file byte sizes without exposing a single filename, OffloadPro sorts all relative leaf descriptors (`relativePath:byteLength`) using ordinal comparison and hashes the joined vector with `SHA-256`:
   $$\text{MerkleRoot} = \text{SHA256}\left(\text{Sort}_{\text{Ordinal}}\left(\{p_1:s_1, \; p_2:s_2, \; \dots, \; p_n:s_n\}\right)\right)$$
3. **Offline Base64 Contact-Sheet Thumbnails:** When generating `_Offload_Certificate.html`, `ffmpeg` extracts video keyframes directly into a `.NET` `MemoryStream` (`-f image2pipe pipe:1`) and embeds them as inline `data:image/jpeg;base64,...` URIs labeled generically (`Clip #1 (.MOV)`), leaving zero temporary image files on disk.

---

## 3. Filesystem & On-Set Cart Safety Guards

1. **System Directory Blocklist (`Assert-SafeTargetPath`):** Blocks any read or mutating operation targeting `C:\Windows`, `C:\Program Files`, `C:\Program Files (x86)`, `C:\ProgramData`, `C:\System Volume Information`, or mutating operations on `C:\` root.
2. **NTFS Junction & Symlink Loop Immunity:** Directory walks explicitly filter out `[System.IO.FileAttributes]::ReparsePoint` (and `robocopy` commands enforce `/XJ`) so cyclical symlinks or junctions can never cause infinite recursion.
3. **3-Tier Sidecar Protection Invariant:** Cleanup operations (`Invoke-MacMetadataForensics.ps1` and `-MacMode clean`) strictly target Tier-2 OS clutter (`._*`, `.DS_Store`, `Thumbs.db`, `desktop.ini`) and **never** delete Tier-1 creative sidecars (`.AAE`, `.XMP`, `.SRT`, `.XML`, `.BIM`, `.CPI`, `.MPL`, `.VTT`, `.CUBE`, `.3DL`, `.THM`, `.LRV`).
4. **Pre-Flight Free-Space & Roll-Collision Gates:**
   - Requires `AvailableFreeSpace >= PayloadBytes + max(64 MB, 5% Payload)` on all destination drives before copying starts.
   - Blocks accidental roll collisions if a destination folder already contains files with identical relative paths but different byte sizes (`[DIT ROLL-COLLISION GUARD BLOCKED]`).
5. **Win32 `SetThreadExecutionState` Sleep Guard:** Holds `ES_CONTINUOUS | ES_SYSTEM_REQUIRED` via `kernel32.dll` inside a `try/finally` block during offloads and audits so Windows cannot enter standby or suspend USB/NVMe controllers mid-operation.

---

## 4. Shift-Left Raw Sector Wiper Prevention & Hardware Locks (`Clear-CameraCard`)

To eliminate wiper-malware primitives and prevent accidental data loss:
1. **Physical Removable Media Hardware Lock:** Raw sector writes (`\\.\X:`) are **strictly restricted** to drives where `DriveInfo.DriveType -eq Removable` (USB flash, SDXC, CFexpress). Operating on `Fixed` (internal SSDs/HDDs), `Network` (SAN/NAS), or `RAMDisk` drives is hard-blocked and throws a `SECURITY VIOLATION BLOCKED` exception even if `-Force` is supplied.
2. **Strict UNC / Network Path Blacklist:** Targets starting with `\\` (other than raw device paths `\\.\`) are rejected immediately.
3. **Synthetic Image File Guard:** Non-drive targets must be explicit `.bin`, `.img`, or `.raw` files, preventing arbitrary overwrite of existing `.dll`, `.exe`, or OS files.
4. **Win32 Kernel Volume Lock Validation:** Calls to `kernel32!DeviceIoControl` (`FSCTL_LOCK_VOLUME` `0x00090018` and `FSCTL_DISMOUNT_VOLUME` `0x00090020`) must return non-zero (`true`). If an Explorer handle or antivirus process holds an open lock, the operation immediately aborts without touching raw disk sectors.

---

## 5. Ledger Re-Scan Anti-Contamination & Argument Sanitization

1. **Manifest Anti-Contamination Guard:** When generating ASC-MHL or MHL v1.1 manifests, `New-MhlAndCertificate` automatically blacklists `ascmhl/` directories, `*.mhl`, `*.ale`, `*.csv`, and `*.html` reports. Re-running or resuming an offload will never hash prior manifest generations into new ledgers.
2. **Subprocess Path Escaping:** Calls to `ffmpeg` and `ffprobe` sanitize file paths, quotes, and colons to prevent shell escape and argument injection attacks.
