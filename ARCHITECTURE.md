# System Architecture & Mathematical Foundations (`OffloadPro DIT Studio v3.3`)

This document details the low-level systems engineering, filesystem geometry, statistical modeling, and browser security architecture powering **OffloadPro DIT Studio**.

---

## 1. The Zero-Server Static Data-Bus Pattern (`file://` CORS Bypass)

Most local web dashboards spin up a `localhost` HTTP server (Node.js, Python, or Go), which introduces background daemon processes, open local TCP ports, DNS rebinding / CSRF risks, and `npm` dependency sprawl.

When running purely offline over `file://`, modern browsers enforce an **opaque `null` origin** per local file, blocking `fetch('./telemetry.json')` under the Same-Origin Policy (CORS).

**How OffloadPro Solves This Without a Server:**
1. **Static `<script>` Data Bus (`public/offloadpro-telemetry.js`):** PowerShell serializes aggregate volume and pre-flight metrics directly into a JavaScript assignment (`window.__OFFLOADPRO_TELEMETRY__ = {...};`). Because `<script src="offloadpro-telemetry.js">` is exempt from `file://` `fetch()` restrictions, `public/index.html` loads hardware telemetry instantaneously with zero open ports.
2. **Browser-Native `webkitdirectory` + WebCrypto Engine:** Users can also select any folder directly inside `public/index.html`. The browser computes 3-tier sidecar taxonomy, ECDF quantiles, and a 256-bit `SHA-256` Merkle Root in memory using `window.crypto.subtle.digest('SHA-256', ...)`.

```
+-------------------------------------------------------------------+
|                     PowerShell 5.1 / 7+ Engine                    |
|  - Get-Volume / Get-PhysicalDisk / Win32_LogicalDisk (S.M.A.R.T.) |
|  - Single-Read 4 MB .NET FileStream Inline Hash & Multi-Write     |
|  - RunspacePool Full-Roll ASC-MHL Sealer & FFprobe/FFmpeg Audit   |
+---------------------------------+---------------------------------+
                                  |
                                  v (Writes aggregate-only JS bus)
+-------------------------------------------------------------------+
|                   public/offloadpro-telemetry.js                  |
|            window.__OFFLOADPRO_TELEMETRY__ = { ... };             |
+---------------------------------+---------------------------------+
                                  |
                                  v (Loaded via <script> over file://)
+-------------------------------------------------------------------+
|                         public/index.html                         |
|  - Offline Volume Bay & ThinkStats2 ECDF / Pareto Visualizer      |
|  - 5-Second Browser-Native Source vs. Backup Merkle Parity Diff   |
|  - 1-Click Standalone PowerShell & AzCopy v10 Command Dock        |
+-------------------------------------------------------------------+
```

---

## 2. Single-Read Multi-Destination `.NET` Stream Pipeline

Standard two-pass copying reads every byte off an SD card during the copy phase and then reads the SD card a second time to compute source checksums—doubling flash thermal stress and USB bus time.

In [`Copy-SingleReadMultiWrite`](./scripts/Invoke-OffloadProEngine.ps1), OffloadPro opens a single `4 MB` (`4,194,304` byte) buffer over the source file (`[System.IO.File]::Open`):
1. Reads each `4 MB` chunk from the SD card **once** into RAM.
2. Feeds the chunk into `.NET` `TransformBlock()` (`SHA256`, `MD5`, or `SHA1`).
3. Writes the same RAM buffer out to Destination #1 (`E:\`) and optional Destination #2 (`F:\`) simultaneously.
4. Finalizes the source hash in RAM (`TransformFinalBlock`) and immediately records it for **zero-re-read 100% Full-Roll `.mhl` sealing**.
5. Reads back the written destination file(s) to prove zero bus or controller corruption occurred during the write phase.

---

## 3. Filesystem Block-Slack Geometry (`exFAT` 128 KB vs. `NTFS` 4 KB)

Why does a `128 GB` SD card formatted as `exFAT` often report `400+ MB` more "Used Space" on the card than the total size of the copied folder on an `NTFS` SSD?

Large SDXC cards (`64 GB` – `1 TB`) default to a **`128 KB` (`131,072` byte) Allocation Unit (Cluster) Size** on `exFAT`, whereas Windows `NTFS` volumes default to **`4 KB` (`4,096` byte) clusters**.

When a card is mounted on macOS, Finder creates a `4,096`-byte `._*` AppleDouble companion file for every media file:
- **On `exFAT` (`128 KB` clusters):** Every `4 KB` `._*` file consumes an entire `128 KB` allocation unit, wasting $128\text{ KB} - 4\text{ KB} = 124\text{ KB}$ of **cluster slack**. Across $N = 3,180$ files, `._*` files alone waste:
  $$\text{Slack}_{\text{exFAT}} = 3,180 \times 124\text{ KB} \approx 394.3\text{ MB}$$
- **On `NTFS` (`4 KB` clusters):** Each `4,096`-byte `._*` file fits inside a single `4 KB` cluster with $0\text{ bytes}$ of slack waste ($3,180 \times 4\text{ KB} \approx 12.4\text{ MB}$ total).

OffloadPro calculates this exact per-file modulo slack (`131072 - (Length % 131072)`) during Pre-Flight X-Ray so DITs and hobbyists never mistake `exFAT` block slack for missing media files.

---

## 4. Statistical Modeling (*ThinkStats2* ECDF, Pareto Concentration & Bivariate ETA)

Camera cards exhibit extreme positive skew ($\text{Mean } \mu \gg \text{Median } P_{50}$): thousands of small `.JPG`, `.AAE`, `.XMP`, and audio files coexist with a handful of multi-gigabyte `4K`/`6K` `.MOV`/`.MP4` video clips.

1. **Empirical Cumulative Distribution Function (ECDF) Quantiles:** OffloadPro computes $P_{10}, P_{25}, P_{50}, P_{75}, P_{90}, P_{99}, \text{Max}$, and the **Pareto Top-10% Byte Share** (typically `55%–80%` of total card gigabytes reside in the largest `10%` of files).
2. **The Inspection Paradox & Dying Card Rescue Mode:** Because `~85%` of individual files sit in the smallest byte buckets (`< 10 MB`), sorting the transfer queue ascending by file size (`-RescueMode`) rescues nearly `90%` of total file count in the first few minutes before sustained multi-gigabyte video reads overheat a failing flash controller.
3. **Bivariate Transfer & Audit ETA Model:**
   $$T(N, B) = \alpha \cdot N + \beta \cdot B$$
   Where $N$ is total file count (capturing per-file NTFS directory entry, handle creation, and `ffprobe` process spawn overhead $\alpha$) and $B$ is total megabyte volume (capturing sequential I/O and stream decode throughput $\beta$).
