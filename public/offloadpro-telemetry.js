// Generic default telemetry snapshot for offline file:// Studio launch (Zero personal paths or filenames)
window.__OFFLOADPRO_TELEMETRY__ = {
  generatedAt: "2026-11-03T00:00:00Z",
  drives: [
    {
      driveLetter: "D",
      root: "D:\\",
      label: "CAM_SDXC_CARD",
      fileSystem: "exFAT",
      driveType: "Removable",
      allocationUnitBytes: 131072,
      sizeBytes: 128000000000,
      freeBytes: 34200000000,
      usedBytes: 93800000000,
      hasSpotlight: true,
      hasTrashes: true,
      serialNumber: "EXFAT-SD01",
      isReadOnly: false,
      smartHealth: "Healthy",
      mediaType: "Removable"
    },
    {
      driveLetter: "E",
      root: "E:\\",
      label: "ARCHIVE_NVME_01",
      fileSystem: "NTFS",
      driveType: "Fixed",
      allocationUnitBytes: 4096,
      sizeBytes: 2000000000000,
      freeBytes: 1420000000000,
      usedBytes: 580000000000,
      hasSpotlight: false,
      hasTrashes: false,
      serialNumber: "NTFS-ARC1",
      isReadOnly: false,
      smartHealth: "Healthy",
      mediaType: "SSD"
    }
  ],
  preflight: {
    targetPath: "E:\\Backups\\Camera_Offload_001",
    exists: true,
    realFilesCount: 3180,
    realFilesBytes: 93250000000,
    creativeSidecarsCount: 42,
    creativeSidecarsBytes: 184320,
    livePhotoPairsCount: 190,
    spannedClipGroupsCount: 4,
    spanGapWarnings: [],
    sameSizeDuplicateCount: 0,
    sameSizeDuplicateBytes: 0,
    priorMhlMatchedCount: 3180,
    macAppleDoubleCount: 3180,
    macAppleDoubleBytes: 13025280,
    dsStoreCount: 24,
    systemForensicFilesCount: 68,
    systemForensicBytes: 28400000,
    zeroByteRealFiles: 0,
    extensions: {
      ".mov": { count: 1420, bytes: 81400000000 },
      ".mp4": { count: 210, bytes: 8200000000 },
      ".jpg": { count: 1390, bytes: 3250000000 },
      ".wav": { count: 118, bytes: 399815680 },
      ".aae": { count: 42, bytes: 184320 }
    },
    estimatedExfatSlackBytes: 419430400,
    thinkStats: {
      n: 3180,
      minKB: 4.0,
      p10MB: 1.4,
      p25MB: 3.1,
      medianMB: 9.2,
      meanMB: 29.32,
      p75MB: 34.8,
      p90MB: 78.5,
      p99MB: 245.0,
      maxMB: 612.4,
      meanToMedianRatio: 3.19,
      top10PctByteShare: 58.4,
      buckets: [
        { label: "< 1 MB", count: 220, filePct: 6.9, bytePct: 0.2 },
        { label: "1–10 MB", count: 1480, filePct: 46.5, bytePct: 8.4 },
        { label: "10–50 MB", count: 1090, filePct: 34.3, bytePct: 33.0 },
        { label: "50–150 MB", count: 310, filePct: 9.7, bytePct: 31.2 },
        { label: "150+ MB", count: 80, filePct: 2.5, bytePct: 27.2 }
      ],
      bivariateEtaSec: {
        copySec: 912,
        level1HashSec: 890,
        level2FfprobeSec: 73,
        level3DeepDecodeSec: 3140
      }
    },
    merkleStructureRoot: "E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855"
  },
  jobs: [
    {
      id: "job-offline-verified",
      name: "Camera_Offload_001 (SHA256 • Pure PowerShell Verified)",
      type: "SINGLE_READ_INLINE_OFFLOAD",
      source: "D:\\",
      destinations: ["E:\\Backups\\Camera_Offload_001"],
      algorithm: "SHA256",
      macMode: "forensic_split",
      rescueMode: false,
      status: "COMPLETED_VERIFIED",
      safeToFormat: true,
      trafficLight: "AMBER_SINGLE_COPY",
      stats: {
        totalFiles: 3180,
        copiedFiles: 3180,
        totalBytes: 93250000000,
        bytesCopied: 93250000000,
        bytesVerifiedL1: 93250000000,
        filesCheckedL2: 3138,
        filesCheckedL3: 3138,
        speedMBps: 98.4,
        failedTransfer: 0,
        hashMismatchesL1: 0,
        corruptContainersL2: 0,
        corruptStreamsL3: 0
      },
      logs: [
        "[Pure PowerShell Engine] Level 1 Bit-for-Bit Hash Check: 0 Mismatches (100% Verified)",
        "[Pure PowerShell Engine] Level 2 FFprobe Container & moov Atom Check: 0 Corrupt Containers",
        "[Pure PowerShell Engine] Level 3 FFmpeg Deep End-to-End Stream Decode: 0 Corrupt Streams (Exit=0)",
        "[Pure PowerShell Engine] Architecture: 100% Offline Static HTML + Native PowerShell (Zero Node.js)"
      ]
    }
  ]
};
