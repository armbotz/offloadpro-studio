# Reversible DIT Card Restore Engine (Un-Invert 2 MiB Header)
function Invoke-RestoreCard {
    param(
        [string]$CardPath
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
            throw "SECURITY VIOLATION BLOCKED: Cannot restore system drive ($cardRoot)!"
        }

        # HARD LOCK: NEVER allow raw sector writes on Fixed, Network, or Virtual drives
        $driveInfo = New-Object System.IO.DriveInfo($cardRoot)
        if ($driveInfo.DriveType -ne [System.IO.DriveType]::Removable) {
            throw "SECURITY VIOLATION BLOCKED: Drive $cardRoot is marked as '$($driveInfo.DriveType)'. Raw sector operations are strictly restricted to physical Removable Media (USB/SD/CFexpress). Action aborted."
        }
    }
    $targetDeviceOrFile = if ($isFileTarget) {
        $safeCard
    } else {
        "\\.\$($cardRoot.TrimEnd('\'))"
    }

    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "OffloadPro v4.3 Reversible DIT Card Restoration Engine" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan

    $bufferLen = 2 * 1024 * 1024
    $buf = New-Object byte[] $bufferLen

    $fs = New-Object System.IO.FileStream($targetDeviceOrFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::ReadWrite)
    try {
        if (-not $isFileTarget) {
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
            throw "Failed to read header from $targetDeviceOrFile"
        }

        # Invert bits again (XOR 0xFF reverts inverted bytes back to original)
        for ($i = 0; $i -lt $bytesRead; $i++) {
            $buf[$i] = [byte]($buf[$i] -bxor 0xFF)
        }

        $fs.Seek(0, [System.IO.SeekOrigin]::Begin) | Out-Null
        $fs.Write($buf, 0, $bytesRead)
        $fs.Flush($true)

        if (-not $isFileTarget) {
            $bytesRet = [uint32]0
            [void][OffloadPro.DiskControl]::DeviceIoControl($fs.SafeFileHandle.DangerousGetHandle(), [uint32]0x0009001C, [IntPtr]::Zero, 0, [IntPtr]::Zero, 0, [ref]$bytesRet, [IntPtr]::Zero)
        }
    } finally {
        $fs.Dispose()
    }

    Write-Host "[CARD RESTORE COMPLETE] Restored $bytesRead bytes. File system and partitions returned to original readable state." -ForegroundColor Green

    return [PSCustomObject]@{
        target        = $targetDeviceOrFile
        bytesRestored = $bytesRead
        status        = 'RESTORED'
    }
}
