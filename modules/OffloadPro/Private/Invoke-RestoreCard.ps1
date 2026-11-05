# Reversible DIT Card Restore Engine (Un-Invert 2 MiB Header)
function Invoke-RestoreCard {
    param(
        [string]$CardPath
    )
    $safeCard = Assert-SafeTargetPath -InputPath $CardPath -IsMutating $true
    $isFileTarget = [System.IO.File]::Exists($safeCard)

    if (-not $isFileTarget) {
        $cardRoot = [System.IO.Path]::GetPathRoot($safeCard)
        $sysRoot  = [System.IO.Path]::GetPathRoot($env:SystemDrive)
        if ($cardRoot -eq $sysRoot -or $cardRoot.ToUpperInvariant().StartsWith('C:')) {
            throw "BLOCKED: Cannot restore system drive ($cardRoot)!"
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
            [void][OffloadPro.DiskControl]::DeviceIoControl($fs.SafeFileHandle.DangerousGetHandle(), [uint32]0x00090018, [IntPtr]::Zero, 0, [IntPtr]::Zero, 0, [ref]$bytesRet, [IntPtr]::Zero)
            [void][OffloadPro.DiskControl]::DeviceIoControl($fs.SafeFileHandle.DangerousGetHandle(), [uint32]0x00090020, [IntPtr]::Zero, 0, [IntPtr]::Zero, 0, [ref]$bytesRet, [IntPtr]::Zero)
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
