# Reversible DIT Safe Card Release / Fake-Format Engine
function Invoke-FakeFormatCard {
    param(
        [string]$CardPath,
        [string]$VerifiedBackupPath,
        [switch]$Force
    )
    if ($CardPath.StartsWith('\\') -and -not $CardPath.StartsWith('\\.\')) {
        throw "SECURITY VIOLATION BLOCKED: Network UNC paths are strictly forbidden."
    }
    $safeCard = Assert-SafeTargetPath -InputPath $CardPath -IsMutating $true
    $isFileTarget = [System.IO.File]::Exists($safeCard)

    if ($isFileTarget) {
        $ext = [System.IO.Path]::GetExtension($safeCard).ToLowerInvariant()
        if ($ext -notin @('.bin', '.img', '.raw')) {
            throw "SECURITY VIOLATION BLOCKED: File target must be a synthetic disk image (.bin, .img, .raw)."
        }
    } else {
        $cardRoot = [System.IO.Path]::GetPathRoot($safeCard)
        $sysRoot  = [System.IO.Path]::GetPathRoot($env:SystemDrive)
        if ($cardRoot -eq $sysRoot -or $cardRoot.ToUpperInvariant().StartsWith('C:')) {
            throw "SECURITY VIOLATION BLOCKED: Cannot modify system drive ($cardRoot)!"
        }

        # HARD LOCK: NEVER allow raw sector writes on Fixed, Network, or Virtual drives
        $driveInfo = New-Object System.IO.DriveInfo($cardRoot)
        if ($driveInfo.DriveType -ne [System.IO.DriveType]::Removable) {
            throw "SECURITY VIOLATION BLOCKED: Drive $cardRoot is marked as '$($driveInfo.DriveType)'. Raw sector operations are strictly restricted to physical Removable Media (USB/SD/CFexpress). Action aborted."
        }
    }

    # Verify backup parity before allowing fake-format
    if (-not [string]::IsNullOrWhiteSpace($VerifiedBackupPath)) {
        $safeBackup = Assert-SafeTargetPath -InputPath $VerifiedBackupPath -IsMutating $false
        $cmp = Invoke-CompareArchives -ArchiveA $safeCard -ArchiveB $safeBackup
        if (-not $cmp.exactParity -and (-not $Force)) {
            throw "SAFETY GATE BLOCKED: Card and backup do not have 100% Merkle parity! Backup missing files or has size drift. Card format blocked."
        }
    }

    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "OffloadPro v4.3 Reversible DIT Fake-Format Engine" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan

    $targetDeviceOrFile = if ($isFileTarget) {
        $safeCard
    } else {
        "\\.\$($cardRoot.TrimEnd('\'))"
    }

    $backupHeaderPath = if (-not [string]::IsNullOrWhiteSpace($VerifiedBackupPath)) {
        $baseNameClean = if ($isFileTarget) { [System.IO.Path]::GetFileNameWithoutExtension($safeCard) } else { $cardRoot.TrimEnd('\').Replace(':', '') }
        Join-Path $VerifiedBackupPath "${baseNameClean}_emergency_header_backup.bin"
    } else {
        $baseNameClean = if ($isFileTarget) { [System.IO.Path]::GetFileNameWithoutExtension($safeCard) } else { $cardRoot.TrimEnd('\').Replace(':', '') }
        Join-Path ([System.IO.Path]::GetTempPath()) "OffloadPro_HeaderBackup_${baseNameClean}.bin"
    }

    $bufferLen = 2 * 1024 * 1024 # 2 MiB (MBR/GPT/exFAT Boot Sector)
    $buf = New-Object byte[] $bufferLen

    $fs = New-Object System.IO.FileStream($targetDeviceOrFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::ReadWrite)
    try {
        if (-not $isFileTarget) {
            # FSCTL_LOCK_VOLUME = 0x00090018, FSCTL_DISMOUNT_VOLUME = 0x00090020
            $bytesRet = [uint32]0
            $lockOk = [OffloadPro.DiskControl]::DeviceIoControl($fs.SafeFileHandle.DangerousGetHandle(), [uint32]0x00090018, [IntPtr]::Zero, 0, [IntPtr]::Zero, 0, [ref]$bytesRet, [IntPtr]::Zero)
            if (-not $lockOk) {
                $err = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
                throw "WIN32 LOCK FAILED: FSCTL_LOCK_VOLUME failed on $targetDeviceOrFile (Win32 Error: $err). Volume is locked or in use. Raw modification aborted."
            }
            $dismountOk = [OffloadPro.DiskControl]::DeviceIoControl($fs.SafeFileHandle.DangerousGetHandle(), [uint32]0x00090020, [IntPtr]::Zero, 0, [IntPtr]::Zero, 0, [ref]$bytesRet, [IntPtr]::Zero)
            if (-not $dismountOk) {
                $err = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
                throw "WIN32 DISMOUNT FAILED: FSCTL_DISMOUNT_VOLUME failed on $targetDeviceOrFile (Win32 Error: $err)."
            }
        }

        $bytesRead = $fs.Read($buf, 0, $bufferLen)
        if ($bytesRead -lt 512) {
            throw "Failed to read partition table from $targetDeviceOrFile"
        }

        # Save an emergency un-inverted binary backup file
        [System.IO.File]::WriteAllBytes($backupHeaderPath, $buf)

        # Invert bits (XOR 0xFF) for all read bytes
        for ($i = 0; $i -lt $bytesRead; $i++) {
            $buf[$i] = [byte]($buf[$i] -bxor 0xFF)
        }

        $fs.Seek(0, [System.IO.SeekOrigin]::Begin) | Out-Null
        $fs.Write($buf, 0, $bytesRead)
        $fs.Flush($true)

        if (-not $isFileTarget) {
            # FSCTL_UNLOCK_VOLUME = 0x0009001C
            $bytesRet = [uint32]0
            [void][OffloadPro.DiskControl]::DeviceIoControl($fs.SafeFileHandle.DangerousGetHandle(), [uint32]0x0009001C, [IntPtr]::Zero, 0, [IntPtr]::Zero, 0, [ref]$bytesRet, [IntPtr]::Zero)
        }
    } finally {
        $fs.Dispose()
    }

    Write-Host "[FAKE-FORMAT COMPLETE] Inverted $bytesRead bytes (2 MiB header). Card will prompt for clean in-camera format on next insert." -ForegroundColor Green
    Write-Host "Emergency Header Backup : $(Split-Path -Leaf $backupHeaderPath) (Saved)" -ForegroundColor DarkGray

    return [PSCustomObject]@{
        target           = $targetDeviceOrFile
        bytesInverted    = $bytesRead
        emergencyHeader  = $backupHeaderPath
        status           = 'FAKE_FORMATTED'
    }
}
